function [fluid, system, sol] = fluidFactoryVE(Gt, rock, varargin)
   opt = struct('mu',                   [6e-2*milli 8e-4]*Pascal*second,...
                'rho',                  [760 1200] .* kilogram/meter^3, ...
                'sr',                   0.21, ...
                'sw',                   0.11, ...
                'kwm',                  [0.75, 0.54], ...
                'fullyImplicit',        true, ...
                'rockCompressibility',  1e-5/barsa, ...
                'waterCompressibility', 4.3e-5/barsa, ...
                'gasCompressibility',   4.3e-5/barsa, ...
                'surfaceTopology',      'smooth', ...
                'formulation',          's', ...
                'referencePressure',    100*barsa, ...
                'referenceTemperature', mean(Gt.cells.z) * 30/1e3+273+4, ...
                'dissolution',          false, ...
                'dissolutionSpeed',     inf, ...
                'dissolutionMax',       0.02,...
                'useTabulatedCO2',      false,...
                'implicitTransport',    true ...
                );

    opt = merge_options(opt, varargin{:});
    
    rho = opt.rho;
    mu  = opt.mu;
    rock2D = averageRock(rock, Gt);
    
    if opt.fullyImplicit
        require ad-fi
        % in the ad solvers, gas (phase 3) is CO2 and phases 1/2 are water.
        phaseSub = [2 2 1];
        fluid = initSimpleADIFluid('mu',   mu(phaseSub),...
                                   'rho',  rho(phaseSub),...
                                   'n',   [1 1 1]); 
        % Strip some fields not relevant here
        badfields = {'krW', 'krO','krG','pcOG','pcOW'};
        fluid = rmfield(fluid, badfields(isfield(fluid, badfields)));
        
        % Compressibilities...
        fluid.pvMultR = @(p) 1 + opt.rockCompressibility*(p-opt.referencePressure);
        
        fluid.bW = @(p, varargin) 1 + opt.waterCompressibility*(p-opt.referencePressure);
        fluid.BW = @(p, varargin) 1./fluid.bW(p);
        
        if opt.useTabulatedCO2
            fluid.bG  =  boCO2(opt.referenceTemperature, fluid.rhoG);
        else
            fluid.bG = @(p, varargin) 1 + opt.gasCompressibility*(p-opt.referencePressure);
        end
        fluid.BG = @(p, varargin) 1./fluid.bG(p);
        
        
        fluid = addVERelperm(fluid, Gt, ...
                             'res_water',   opt.sw, ...
                             'res_gas',   opt.sr,...
                             'surf_topo', opt.surfaceTopology);
        if opt.dissolution
            fluid.dis_max = opt.dissolutionMax;
            if isfinite(opt.dissolutionSpeed)
                fluid.dis_rate = opt.dissolutionSpeed*opt.dissolutionMax;
            end
            fluid.rsSat= @(po,rs,flag,varargin) (po*0+1)*opt.dissolutionMax;
            % Recall that "oil" is really water and gas refers to CO2
            phases = {'Oil', 'Gas', 'DisGas',};
        else
            phases = {'Oil', 'Gas'};
        end
        
        s = setupSimCompVe(Gt, rock2D);
        
        system = initADISystem(phases, Gt, rock2D, fluid,...
                                    'simComponents', s, ...
                                    'use_ecltol',    false);
        if opt.dissolution
            % Override equations with the actual black oil-like fluid
            system.getEquations = @eqsfiBlackOilExplicitWellsOGVE_new;
            system.stepFunction = @(state0, state, meta, dt, W, G, system, varargin)...
                   stepBlackOilOGVE(state0, state, meta, dt, G, W, system, fluid, varargin{:});

        else
            % Override with ve-based oil-gas fluid
            system.getEquations = @eqsfiOGExplicitWellsVE;   
        end
    else
        switch(lower(opt.formulation))
            case 'h'
                % Fluid for original VE formulation based on plume height
                fluid    = initVEFluidHForm(Gt, 'mu' ,  opt.mu, ...
                                                    'rho',  opt.rho, ...
                                                    'sr',   opt.sr, ...
                                                    'sw',   opt.sw,...
                                                    'kwm',  opt.kwm);
            case 's'
                % fluid for standard incomp MRST solvers based on saturations            
                fluid = initSimpleVEFluid_s('mu' ,      opt.mu ,...
                                                'rho',      opt.rho, ...
                                                'height',   Gt.cells.H,...
                                                'sr',       [opt.sr, opt.sw],...
                                                'kwm',      opt.kwm);                                                        
                fluid.sr = opt.sr;
                fluid.sw = opt.sw;
        end
        system = [];
    end
    
    % Finally, set up a initialized state matching the fluid
    sol = initResSolVE(Gt, opt.referencePressure, 0);
    sol.pressure = rho(2)*norm(gravity()).*Gt.cells.z;
    [sol.rs, sol.sGmax, sol.s] = deal(zeros(Gt.cells.num,1));
end
