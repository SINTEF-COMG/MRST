function [problem, state] = transportEquationOilWaterDG(state0, state, model, dt, drivingForces, varargin)

    opt = struct('Verbose', mrstVerbose, ...
                 'reverseMode', false,...
                 'scaling', [],...
                 'resOnly', false,...
                 'history', [],...
                 'solveForWater', false, ...
                 'solveForOil', true, ...
                 'iteration', -1, ...
                 'stepOptions', []);  % Compatibility only
    
    opt   = merge_options(opt, varargin{:});
    W     = drivingForces.W;
    op    = model.operators;
    fluid = model.fluid;
    rock  = model.rock;
    G     = model.G;
    disc  = model.disc;
        
    assert(~(opt.solveForWater && opt.solveForOil));
        
    if ~isfield(state, 'cells')
        [state.cells, state0.cells] = deal((1:G.cells.num)');
    end
    
    if opt.iteration == 1
        % If we are at the first iteration, we try to solve using maximum
        % degree in all cells
        state.degree = repmat(disc.degree, G.cells.num, 1);
        % For cells that previously had less than nDof unknowns, we must
        % map old dofs to new
        state        = disc.mapDofs(state, state0);
        
    end
    % Update discretizaiton information. This is carried by the state
    % variable, and holds the number of dofs per cell + dof position in
    % state.sdof
    state = disc.updateDisc(state);
    state = disc.getCellSaturation(state);
    
    % Properties from current timestep
    [p , sWdof , wellSol] = model.getProps(state , 'pressure', 'water', 'wellsol');
    % Properties from previous timestep
    [p0, sWdof0         ] = model.getProps(state0, 'pressure', 'water'           );
    sW = state.s(:,1);
    
    % If timestep has been split relative to pressure, linearly interpolate in
    % pressure.
    pFlow = p;
    if isfield(state, 'timestep')
        dt_frac = dt/state.timestep;
        p = p.*dt_frac + p0.*(1-dt_frac);
    end
    
    %Initialization of independent variables ------------------------------

    if ~opt.resOnly
        % ADI variables needed since we are not only computing residuals.
        if ~opt.reverseMode
            sWdof = model.AutoDiffBackend.initVariablesAD(sWdof);
        else
            assert(0, 'Backwards solver not supported for splitting');
        end
    end
    
    % ---------------------------------------------------------------------

    % We will soclve for water saturation dofs
    primaryVars = {'sWdof'};
    nDof        = state.nDof;

    % Get multipliers
    [pvMult, transMult, mobMult, pvMult0] = getMultipliers(model.fluid, p, p0);
    pvMult  = expandSingleValue(pvMult, G);
    pvMult0 = expandSingleValue(pvMult0, G);
    mobMult = expandSingleValue(mobMult, G);
    T = op.T.*transMult;
    T_all = model.operators.T_all;
    
    % Phase properties
    sO  = 1 - sW;
    gdz = model.getGravityGradient();
    
    [vW, bW, mobW, rhoW, pW, upcW, dpW, muW] = getPropsWater_DG(model, p, T, gdz, mobMult);
    [vO, bO, mobO, rhoO, pO, upcO, dpO, muO] = getPropsOil_DG(model, p, T, gdz, mobMult);
    
    % Fractional flow function
    fW = @(sW, sO, cW, cO) mobW(sW, cW)./(mobW(sW, cW) + mobO(sO, cO));
    
    bW0 = fluid.bW(p0);
    
    
    % Gravity fluxs
    gp = op.Grad(p);
    [Gw, Go] = deal(zeros(G.faces.num, 1));
    Gw(op.internalConn) = gp - dpW;
    Go(op.internalConn) = gp - dpO;
    
    % Add gravity flux where we have a BC.
    bc = drivingForces.bc;
    if ~isempty(bc)

        BCcells = sum(G.faces.neighbors(bc.face,:),2);
        dz = G.cells.centroids(BCcells, :) - G.faces.centroids(bc.face,:);
        g = model.getGravityVector();
        rhoWBC = rhoW(BCcells);
        rhoOBC = rhoO(BCcells);
        
        Gw(bc.face) = rhoWBC.*(dz*g');
        Go(bc.face) = rhoOBC.*(dz*g');
        
    end    
    
    TGw = T_all.*Gw;
    TGo = T_all.*Go;
    TGwc = op.faceFlux2cellVelocity(TGw);
    TGoc = op.faceFlux2cellVelocity(TGo);
    
    % Viscous flux
    vT  = sum(state.flux,2);
    vTc = op.faceFlux2cellVelocity(vT);
    
    % Cell integrand functions---------------------------------------------
        
    % Accumulation term
    acc = @(sW, sW0, c, psi) ...
        (pvMult (c).*rock.poro(c).*bW (c).*sW - pvMult0(c).*rock.poro(c).*bW0(c).*sW0).*psi/dt;
                          
    % Flux term         
    flux1 = @(sW,fW,c,grad_psi) ...
        bW(c).*fW.*(sum(vTc(c,:).*grad_psi,2) + mobO(1-sW,c).*sum((TGwc(c,:) - TGoc(c,:)).*grad_psi,2));

    cellIntegral = disc.cellInt(@(sW, sW0, fW, c, psi, grad_psi) ...
        acc(sW, sW0, c, psi) - flux1(sW, fW, c,grad_psi), fW, (1:G.cells.num)', sWdof, sWdof0, state, state0);
    
    % Surface integrand functions------------------------------------------
    
    % Flux term
    flux2 = @(fWv, fWg, sWv, sWg, c, cv, cg, f, psi) ...
        (bW(cv).*fWv.*vT(f) + bW(cg).*fWg.*mobO(1-sWg,cg).*(TGw(f) - TGo(f))).*psi./G.faces.areas(f);

    faceIntegral = disc.faceFluxInt(flux2, fW, (1:G.cells.num)', sWdof, state, T, vT, {Gw, Go}, {mobW, mobO});
  
    % Water equation-------------------------------------------------------

    water = cellIntegral + faceIntegral;

    % Well contributions---------------------------------------------------
    
    if ~isempty(W)
        
        perf2well = getPerforationToWellMapping(W);
        wc = vertcat(W.cells);

        wflux = zeros(G.cells.num,1);
        wflux(wc) = sum(vertcat(wellSol.flux), 2);
        isInj = wflux > 0;
        compWell = vertcat(W.compi);
        compPerf = zeros(G.cells.num, 2);
        compPerf(wc,:) = compWell(perf2well,:);
        
        integrand = @(sW, sW0, fW, c, psi, grad_psi) ...
            bW(c).*wflux(c).*(fW.*(~isInj(c)) + compPerf(c,1).*( isInj(c))).*psi;

        prod = disc.cellInt(integrand, fW, wc, sWdof, sWdof0, state, state0);
        
        vol = rldecode(G.cells.volumes(wc), nDof(wc), 1);
        ix = disc.getDofIx(state, [], wc);
        water(ix) = water(ix) - prod(ix)./vol;

        % Store well fluxes
        [WC, x, cellNo] = disc.getCubature(wc, 'volume');
        
%         [x, w, nq, ii, jj, cellNo] = makeCellIntegrator(G, wc, disc.degree+1, 'volume');
        x = disc.transformCoords(x, cellNo);
        sWw = disc.evaluateSaturation(x, cellNo, sWdof, state);
%         W = sparse(ii, jj, w);
        
        wflux_W = WC*(bW(cellNo).*wflux(cellNo) ...
                     .*(fW(sWw, 1-sWw, cellNo, cellNo) .*(~isInj(cellNo)) ...
                     + compPerf(cellNo,1).*( isInj(cellNo))));
        wflux_W = wflux_W./G.cells.volumes(wc);
          
        wflux_O = WC*(bO(cellNo).*wflux(cellNo) ...
                     .*((1-fW(sWw, 1-sWw, cellNo, cellNo)).*(~isInj(cellNo)) ...
                     + compPerf(cellNo,2) .*( isInj(cellNo))));
        wflux_O = wflux_O./G.cells.volumes(wc);

        wflux_O = double(wflux_O);
        wflux_W = double(wflux_W);

        for wNo = 1:numel(W)
            perfind = perf2well == wNo;
            state.wellSol(wNo).qOs = sum(wflux_O(perfind));
            state.wellSol(wNo).qWs = sum(wflux_W(perfind));
        end

    end
    
    state.cfl = dt.*sum(abs(vTc)./G.cells.dx,2);
    
    % Add BCs--------------------------------------------------------------
    
    if ~isempty(bc)
        
        % Flux term
        fluxBC = @(fW, sW, c, f, psi) ...
        (bW(c).*fW.*vT(f) + bW(c).*fW.*mobO(1-sW,c).*(TGw(f) - TGo(f))).*psi./G.faces.areas(f);

        bcInt = disc.faceFluxIntBC(fluxBC, fW, sWdof, state, bc);
        
        water = water + bcInt;
        
        
    end
    
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
        
        ix = disc.getDofIx(state, [], cells);
        water(ix) = water(ix) - source(ix)./vol;
        
    end
    
    % Make Linearized problem----------------------------------------------

    eqs   = {water  };
    names = {'water'};
    types = {'cell' };

    if ~model.useCNVConvergence
        pv = rldecode(op.pv, nDof, 1);
        eqs{1} = eqs{1}.*(dt./pv);
    end

    problem = LinearizedProblem(eqs, types, names, primaryVars, state, dt);
    
    if 1
        state.problem = problem;
    end
    
    if model.extraStateOutput
    %     state = model.storebfactors(state, bW, bO, []);
    %     state = model.storeMobilities(state, mobW, mobO, []);
        state = model.storeDensity(state, rhoW, rhoO, []);
    end

end

function v = expandSingleValue(v,G)

    if numel(v) == 1
        v = v*ones(G.cells.num,1);
    end
    
end