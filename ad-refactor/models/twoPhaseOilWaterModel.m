classdef twoPhaseOilWaterModel < physicalModel
    % two phase oil / water system
    properties

    end
    
    methods
        function model = twoPhaseOilWaterModel(G, rock, fluid, varargin)
            opt = struct('deck',  []);
            opt = merge_options(opt, varargin{:});
            
            model.fluid  = fluid;
            model.G   = G;
            
            model.name = 'OilWater_2ph';
            model = model.setupOperators(G, rock, 'deck', opt.deck);
        end
        
        function problem = getEquations(model, state0, state, dt, drivingForces, varargin)
            problem = equationsOilWater(state0, state, dt, ...
                            model.G,...
                            drivingForces,...
                            model.operators,...
                            model.fluid,...
                            varargin{:});
            
        end
        
        function state = updateState(model, state, dx, drivingForces)
            dsMax = model.dsMax;
            dpMax = model.dpMax;
            
            dp = dx{1};
            ds = dx{2};

            ds = sign(ds).*min(abs(ds), dsMax);
            dp = sign(dp).*min(abs(dp), abs(dpMax.*state.pressure));

            state.pressure = state.pressure + dp;
            sw = state.s(:,1) + ds;
            % Cap values
            sw = min(sw, 1); sw = max(sw, 0);

            state.s = [sw, 1-sw];

            dqWs    = dx{3};
            dqOs    = dx{4};
            dpBHP   = dx{5};
            
            if ~isempty(dpBHP)
                dpBHP = sign(dpBHP).*min(abs(dpBHP), abs(dpMax.*vertcat(state.wellSol.bhp)));
                for w = 1:numel(state.wellSol)
                    state.wellSol(w).bhp      = state.wellSol(w).bhp + dpBHP(w);
                    state.wellSol(w).qWs      = state.wellSol(w).qWs + dqWs(w);
                    state.wellSol(w).qOs      = state.wellSol(w).qOs + dqOs(w);
                end
            end
        end
        
    end
end