classdef EquilibriumConstantModel < EquationOfStateModel
    % Equilibrium constant EOS model for problems where functions of the
    % type K(p, T, z) is sufficient to describe the phase behavior
    properties
        equilibriumConstantFunctions
    end
    
    methods
        function model = EquilibriumConstantModel(G, fluid, k_values)
            model = model@EquationOfStateModel(G, fluid);
            model.equilibriumConstantFunctions = k_values;
        end
        
        function [Z_L, Z_V, f_L, f_V] = getCompressibilityAndFugacity(model, P, T, x, y, z, Z_L, Z_V, varargin)
            R = 8.3144598;
            rhoL = model.PropertyModel.computeMolarDensity(P, x, nan, T, true);
            rhoV = model.PropertyModel.computeMolarDensity(P, y, nan, T, false);
            assert(all(P > 0), 'Pressures must be positive!')
            Z_L = P./(rhoL.*R.*T);
            Z_V = P./(rhoV.*R.*T);
            if nargout < 3
                return
            end
            K =  model.evaluateEquilibriumConstants(P, T, z);
            if iscell(x)
                [f_L, f_V] = deal(cell(1, numel(x)));
                for i = 1:numel(x)
                    f_V{i} = y{i};
                    f_L{i} = x{i}.*K{i};
                end
            else
                f_V = y;
                f_L = x.*K;
            end
        end

        function [stable, x, y, L] = performPhaseStabilityTest(model, P, T, z, varargin)
            if isempty(P)
                [stable, x, y] = deal([]);
                return
            end
            K = model.evaluateEquilibriumConstants(P, T, z);
            if isempty(model.PropertyModel.checkStabilityFunction)
                L = model.solveRachfordRice([], K, z);
                L_tol = 1e-10;
                stable = abs(L - 1) <= L_tol| L <= L_tol;
            else
                [stable, L] = model.PropertyModel.checkStabilityFunction(P, T, expandMatrixToCell(z));
            end
            x = model.computeLiquid(L, K, z);
            y = model.computeVapor(L, K, z);
        end
        
        function K = evaluateEquilibriumConstants(model, P, T, z)
            if ~iscell(z)
                z = expandMatrixToCell(z);
                fix = true;
            else
                fix = false;
            end
            K = cellfun(@(fn) fn(P, T, z), model.equilibriumConstantFunctions, 'UniformOutput', false);
            
            mv = 1e16;
            
            for i = 1:numel(K)
                K{i}(K{i} > mv) = mv;
                K{i}(K{i} < 1/mv) = 1/mv;
            end
            if fix
                K = [K{:}];
            end
        end
        
        function [state, report] = stepFunction(model, state, state0, dt, drivingForces, linsolve, nonlinsolve, iteration, varargin)
            P = state.pressure;
            T = state.T;
            z = state.components;
            K = model.evaluateEquilibriumConstants(P, T, z);
            L = repmat(0.5, size(P));
            L0 = state.L;
            state.L = model.solveRachfordRice(L, K, z);
            [stable, state.x, state.y, L_est] = model.performPhaseStabilityTest(P, T, z);
            if isempty(L_est)
                L_est = L0;
            end
            state.L(stable) = double(L_est(stable) > 0.5);
            state.K = K;
            report = model.makeStepReport('Converged', true);
        end
        
        function [state, report] = updateAfterConvergence(model, state0, state, dt, drivingForces)
            [state, report] = updateAfterConvergence@PhysicalModel(model, state0, state, dt, drivingForces);
            state = model.setFlag(state);
            state.x = model.computeLiquid(state);
            state.y = model.computeVapor(state);
            [pureLiquid, pureVapor] = model.getFlag(state);
            state.x(pureVapor, :) = state.components(pureVapor, :);
            state.y(pureLiquid, :) = state.components(pureLiquid, :);
            [state.Z_L, state.Z_V] = model.getCompressibilityAndFugacity(state.pressure, state.T, state.x, state.y);
        end
    end
end
