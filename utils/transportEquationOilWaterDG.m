function [problem, state] = transportEquationOilWaterDG(state0, state, model, dt, drivingForces, varargin)

    opt = struct('Verbose'      , mrstVerbose, ...
                 'reverseMode'  , false      ,...
                 'scaling'      , []         ,...
                 'resOnly'      , false      ,...
                 'history'      , []         ,...
                 'solveForWater', true       , ...
                 'solveForOil'  , false      , ...
                 'iteration'    , -1         , ...
                 'stepOptions'  , []         ); % Compatibility only
    opt      = merge_options(opt, varargin{:});
    
    % Frequently used properties
    op       = model.operators;
    fluid    = model.fluid;
    rock     = model.rock;
    G        = model.G;
    disc     = model.disc;
    flux2Vel = disc.velocityInterp.faceFlux2cellVelocity;
    
    % We may solve for both oil and water simultaneously
    solveAllPhases = opt.solveForWater && opt.solveForOil;
    
    % Prepare state for simulation-----------------------------------------
    if opt.iteration == 1 && ~opt.resOnly 
        if model.tryMaxDegree
            % If we are at the first iteration, we try to solve using
            % maximum degree in all cells
            state.degree(~G.cells.ghost) ...
                             = repmat(disc.degree, nnz(~G.cells.ghost), 1);
        end
        % For cells that previously had less than nDof unknowns, we must
        % map old dofs to new
        state = disc.mapDofs(state, state0);
        
    end
    % Update discretizaiton information. This is carried by the state
    % variable, and holds the number of dofs per cell + dof position in
    % state.sdof
    state0 = disc.updateDofPos(state0);
    state  = disc.updateDofPos(state);
    %----------------------------------------------------------------------
    
    % Properties from current and previous timestep------------------------
    [p , sWdof , sW , sOdof , sO , wellSol] = model.getProps(state , ...
                  'pressure', 'swdof', 'water', 'sodof', 'oil', 'wellsol');
    [p0, sWdof0, sW0, sOdof0, sO0,        ] = model.getProps(state0, ...
                  'pressure', 'swdof', 'water', 'sodof', 'oil'           );
    % If timestep has been split relative to pressure, linearly interpolate
    % in pressure.
    if isfield(state, 'timestep')
        dt_frac = dt/state.timestep;
        p       = p.*dt_frac + p0.*(1-dt_frac);
    end
    %----------------------------------------------------------------------
    
    % Initialization of independent variables -----------------------------
    assert(~opt.reverseMode, 'Backwards solver not supported for splitting');
    if solveAllPhases
        if ~opt.resOnly
            [sWdof, sOdof] = model.AutoDiffBackend.initVariablesAD(sWdof, sOdof);
        end
        primaryVars = {'sWdof', 'sOdof'};
        sTdof = sOdof + sWdof;
    else
        if ~opt.resOnly
            sWdof = model.AutoDiffBackend.initVariablesAD(sWdof);
        end
        primaryVars = {'sWdof'};
        sOdof     = -sWdof;
        ix        = disc.getDofIx(state, 1, Inf);
        sOdof(ix) = 1 + sOdof(ix);
        sTdof     = zeros(size(double(sWdof)));
        sTdof(ix) = 1;
    end
    nDof = state.nDof;
    %----------------------------------------------------------------------

    % Pressure and saturation dependent properties-------------------------
    % Get multipliers
    [pvMult, transMult, mobMult, pvMult0] = getMultipliers(model.fluid, p, p0);
    pvMult  = expandSingleValue(pvMult , G);
    pvMult0 = expandSingleValue(pvMult0, G);
    mobMult = expandSingleValue(mobMult, G);
    T       = op.T.*transMult;
    T_all   = model.operators.T_all;
    
    % Phase properties
    gdz = model.getGravityGradient();
    [vW, bW, mobW, rhoW, pW, upcW, dpW, muW] ...
                             = getPropsWater_DG(model, p, T, gdz, mobMult);
    [vO, bO, mobO, rhoO, pO, upcO, dpO, muO] ...
                             = getPropsOil_DG(model, p, T, gdz, mobMult  );
    bW0 = fluid.bW(p0);
    bO0 = fluid.bO(p0);
    
                           
    % Fractional flow functions
    fW = @(sW, sO, sT, cW, cO) mobW(sW, sT, cW)./(mobW(sW, sT, cW) + mobO(sO, sT, cO));
    fO = @(sW, sO, sT, cW, cO) mobO(sO, sT, cO)./(mobW(sW, sT, cW) + mobO(sO, sT, cO));
    
    % Gravity flux
    gp = op.Grad(p);
    [gW, gO] = deal(zeros(G.faces.num, 1));
    gW(op.internalConn) = gp - dpW;
    gO(op.internalConn) = gp - dpO;
    % Add gravity flux where we have BCs to get correct cell values
    bc = drivingForces.bc;
    if ~isempty(bc)
        BCcells = sum(G.faces.neighbors(bc.face,:), 2);
        dz = G.cells.centroids(BCcells, :) - G.faces.centroids(bc.face,:);
        g = model.getGravityVector();
        rhoWBC = rhoW(BCcells);
        rhoOBC = rhoO(BCcells);
        gW(bc.face) = rhoWBC.*(dz*g');
        gO(bc.face) = rhoOBC.*(dz*g');
    end    
    TgW  = T_all.*gW;          % Gravity volumetric flux, water
    TgO  = T_all.*gO;          % Gravity volumetric flux, oil
    TgWc = flux2Vel(TgW);      % Map to cell velocity
    TgOc = flux2Vel(TgO);
    TgW  = TgW./G.faces.areas; % Convert to gravity flux
    TgO  = TgO./G.faces.areas;
    
    % Viscous flux
    flux  = sum(state.flux,2);   % Total volumetric flux
    vT    = flux./G.faces.areas; % Total flux 
    vTc   = flux2Vel(flux);      % Map face fluxes to cell velocities
    %----------------------------------------------------------------------
    
    % Well contributions---------------------------------------------------
    W = drivingForces.W;
    if ~isempty(W)
        % Total well flux, composition and mappings
        perf2well = getPerforationToWellMapping(W);
        wc        = vertcat(W.cells);
        wflux     = zeros(G.cells.num,1);
        wflux(wc) = sum(vertcat(wellSol.flux), 2)./G.cells.volumes(wc);
        isInj     = wflux > 0;
        compWell  = vertcat(W.compi);
        compPerf  = zeros(G.cells.num, 2);
        compPerf(wc,:) = compWell(perf2well,:);
        
        % Saturations at cubature points
        [~, xcw, cNow] = disc.getCubature(wc, 'volume');
        xcw = disc.transformCoords(xcw, cNow);
        sWW = disc.evaluateSaturation(xcw, cNow, sWdof, state);
        sOW = disc.evaluateSaturation(xcw, cNow, sOdof, state);
        sTW = disc.evaluateSaturation(xcw, cNow, sTdof, state);
        
        % Water well contributions
        integrand = @(psi, gradPsi) bW(cNow).*wflux(cNow)...
            .*(sTW.*fW(sWW, sOW, sTW, cNow, cNow).*(~isInj(cNow)) + compPerf(cNow,1).*isInj(cNow)).*psi;
        srcWW = disc.cellInt(integrand, wc, state, sWdof);
        
        % Oil well contributions
        integrand = @(psi, gradPsi) bO(cNow).*wflux(cNow)...
            .*(sTW.*fO(sWW, sOW, sTW, cNow, cNow).*(~isInj(cNow)) + compPerf(cNow,2).*isInj(cNow)).*psi;
        srcOW = disc.cellInt(integrand, wc, state, sOdof);
                
        % Store well fluxes
        ix     = disc.getDofIx(state, 1, wc);
        wfluxW = double(srcWW(ix));
        wfluxO = double(srcOW(ix));
        for wNo = 1:numel(W)
            perfind = perf2well == wNo;
            state.wellSol(wNo).qWs = sum(wfluxW(perfind));
            state.wellSol(wNo).qOs = sum(wfluxO(perfind));
        end

    end
    %----------------------------------------------------------------------

    % Evaluate saturation at cubature points-------------------------------
    % Cell cubature points
    [~, xc, c] = disc.getCubature((1:G.cells.num)', 'volume');
    xc   = disc.transformCoords(xc, c);
    sWc  = disc.evaluateSaturation(xc, c, sWdof , state );
    sWc0 = disc.evaluateSaturation(xc, c, sWdof0, state0);
    sOc  = disc.evaluateSaturation(xc, c, sOdof , state );
    sOc0 = disc.evaluateSaturation(xc, c, sOdof0, state0);
    sTc  = disc.evaluateSaturation(xc, c, sTdof , state );
    
    % Face cubature points
    [WF, xf, ~, fNo] = disc.getCubature((1:G.cells.num)', 'surface');
    % Upstream cells
    [~, ~, cfV, cfG] = disc.getSaturationUpwind(fNo, xf, T, flux, ...
                            {gW, gO}, {mobW, mobO}, {sWdof, sOdof}, state);
    
    xfV   = disc.transformCoords(xf, cfV(:,1));
    sWfV  = disc.evaluateSaturation(xfV, cfV(:,1), sWdof, state);
    sTWfV = disc.evaluateSaturation(xfV, cfV(:,1), sTdof, state);
    xfG   = disc.transformCoords(xf, cfG(:,1));
    sWfG  = disc.evaluateSaturation(xfG, cfG(:,1), sWdof, state);
    sTWfG = disc.evaluateSaturation(xfG, cfG(:,1), sTdof, state);
                       
    xfV   = disc.transformCoords(xf, cfV(:,2));
    sOfV  = disc.evaluateSaturation(xfV, cfV(:,2), sOdof, state);
    sTOfV = disc.evaluateSaturation(xfV, cfV(:,2), sTdof, state);
    xfG   = disc.transformCoords(xf, cfG(:,2));
    sOfG  = disc.evaluateSaturation(xfG, cfG(:,2), sOdof, state);
    sTOfG = disc.evaluateSaturation(xfG, cfG(:,2), sTdof, state);
    
    % Water equation-------------------------------------------------------
    if opt.solveForWater
        % Cell values
        fWc   = fW(sWc,sOc,sTc,c,c);
        mobOc = mobO(sOc,sTc,c);
        % Face values
        fWfV   = fW(sWfV, sOfV, sTWfV, cfV(:,1), cfG(:,2));
        fWfG   = fW(sWfG, sOfG, sTWfG, cfG(:,1), cfG(:,2));
        mobOfG = mobO(sOfG,sTOfG,cfG(:,2));
        % Accumulation term
        acc = @(psi) (pvMult(c) .*rock.poro(c).*bW(c) .*sWc - ...
                      pvMult0(c).*rock.poro(c).*bW0(c).*sWc0).*psi/dt;
        % Convection term
        conv = @(gradPsi) bW(c).*fWc.*(disc.dot(vTc(c,:),gradPsi) ...
                        + mobOc.*disc.dot(TgWc(c,:) - TgOc(c,:),gradPsi));
        integrand = @(psi, gradPsi) acc(psi) - conv(gradPsi);
        % Integrate integrand*psi{dofNo} over all cells for dofNo = 1:nDof
        cellIntegral = disc.cellInt(integrand, [], state, sWdof);
        % Flux term
        flux = @(psi) ...
            (sTWfV.*bW(cfV(:,1)).*fWfV.*vT(fNo) ...
                  + bW(cfG(:,1)).*fWfG.*mobOfG.*(TgW(fNo) - TgO(fNo))).*psi;
        % Integrate integrand*psi{dofNo} over all cells surfaces for dofNo = 1:nDof
        faceIntegral = disc.faceFluxInt(flux, [], state, sWdof);
        % Sum integrals
        water = cellIntegral + faceIntegral;
        % Add well contributions
        if ~isempty(W)
            ix = disc.getDofIx(state, Inf, wc);
            water(ix) = water(ix) - srcWW(ix);
        end
        
    end
    %----------------------------------------------------------------------
    
    % Oil equation---------------------------------------------------------
    if opt.solveForOil
         % Cell values
        fOc   = fO(sWc, sOc, sTc, c, c);
        mobWc = mobW(sWc,sTc,c);
        % Face values
        fOfV   = fO(sWfV, sOfV, sTOfV, cfV(:,1), cfG(:,2));
        fOfG   = fO(sWfG, sOfG, sTOfG, cfG(:,1), cfG(:,2));
        mobWfG = mobW(sWfG,sTWfG,cfG(:,1));
        % Accumulation term
        acc = @(psi) (pvMult(c) .*rock.poro(c).*bO(c) .*sOc - ...
                      pvMult0(c).*rock.poro(c).*bO0(c).*sOc0).*psi/dt;
        % Convection term
        conv = @(gradPsi) bO(c).*fOc.*(disc.dot(vTc(c,:),gradPsi) ...
                        + mobWc.*disc.dot(TgOc(c,:) - TgWc(c,:),gradPsi));
        integrand = @(psi, gradPsi) acc(psi) - conv(gradPsi);
        % Integrate integrand*psi{dofNo} over all cells for dofNo = 1:nDof
        cellIntegral = disc.cellInt(integrand, [], state, sWdof);
        % Flux term
        flux = @(psi) ...
            (sTOfV.*bO(cfV(:,2)).*fOfV.*vT(fNo) ...
                  + bO(cfG(:,2)).*fOfG.*mobWfG.*(TgO(fNo) - TgW(fNo))).*psi;
        % Integrate integrand*psi{dofNo} over all cells surfaces for dofNo = 1:nDof
        faceIntegral = disc.faceFluxInt(flux, [], state, sWdof);
        % Sum integrals
        oil = cellIntegral + faceIntegral;
        % Add well contributions
        if ~isempty(W)
            ix = disc.getDofIx(state, Inf, wc);
            oil(ix) = oil(ix) - srcOW(ix);
        end
    end
    %----------------------------------------------------------------------

    % Add BCs--------------------------------------------------------------
    if ~isempty(bc)
        fluxBC = @(sW, fW, c, f, psi) ...
        (bW(c).*fW.*vT(f) + bW(c).*fW.*mobO(1-sW,c).*(TgW(f) - TgO(f))).*psi;
        bcInt = disc.faceFluxIntBC(model, fluxBC, bc, state, sWdof, fW);        
        water = water + bcInt;
    end
    %----------------------------------------------------------------------
    
    % Add sources----------------------------------------------------------
    src = drivingForces.src;
    if ~isempty(src)
        cells = src.cell;
        rate = src.rate;
        sat = src.sat;
        integrand = @(c, psi) ...
                        bW(c).*rate.*sat(:,1).*psi;
        source = disc.cellInt(@(sW, sW0, fW, c, psi, grad_psi) ...
            integrand(c, psi), fW, cells, sWdof, sWdof0, state, state0);
        
        vol = rldecode(G.cells.volumes(cells), nDof(cells), 1);
        
        ix = disc.getDofIx(state, Inf, cells);
        water(ix) = water(ix) - source(ix)./vol;
    end
    %----------------------------------------------------------------------
    
    % Make Linearized problem----------------------------------------------
    if solveAllPhases
        eqs = {water, oil};
        names = {'water', 'oil'};    
        types = {'cell', 'cell'};
    elseif opt.solveForWater
        eqs   = {water  };
        names = {'water'};
        types = {'cell' };
    elseif opt.solveForOil
        eqs   = {oil   };
        names = {'oil' };
        types = {'cell'};
    end


    if ~model.useCNVConvergence
        for eqNo = 1:(opt.solveForOil+opt.solveForWater)
            eqs{eqNo} = eqs{eqNo}.*(dt./op.pv);
        end
    end

    problem = LinearizedProblem(eqs, types, names, primaryVars, state, dt);
    
    if model.extraStateOutput
        state     = model.storeDensity(state, rhoW, rhoO, []);
        state.cfl = dt.*sum(abs(vTc)./G.cells.dx,2);
    end
    
    if isfield(G, 'parent')
        ix = disc.getDofIx(state, Inf, ~G.cells.ghost);
        
        for eqNo = 1:numel(problem.equations)
            eq = problem.equations{eqNo};
            if isa(eq, 'ADI')
                eq.val = eq.val(ix);
                eq.jac = cellfun(@(j) j(ix,ix), eq.jac, 'unif', false);
            else
                eq = eq(ix);
            end
            problem.equations{eqNo} = eq;
        end
    end

end

function v = expandSingleValue(v,G)

    if numel(double(v)) == 1
        v = v*ones(G.cells.num,1);
    end
    
end