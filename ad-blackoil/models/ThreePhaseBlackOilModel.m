classdef ThreePhaseBlackOilModel < ReservoirModel
    % Three phase with optional dissolved gas and vaporized oil
    properties
        % Determines if gas can be dissolved into the oil phase
        disgas
        % Determines if oil can be vaporized into the gas phase
        vapoil
        
        % Maximum Rs/Rv increment
        drsMaxRel
        drsMaxAbs
        
        % Use alternate tolerance scheme
        useCNVConvergence
        
        % CNV tolerance (inf-norm-like)
        toleranceCNV;
        
        % MB tolerance values (2-norm-like)
        toleranceMB;
        % Well tolerance if CNV is being used
        toleranceWellBHP;
        % Well tolerance if CNV is being used
        toleranceWellRate;
        
        % Update wells
        
    end
    
    methods
        function model = ThreePhaseBlackOilModel(G, rock, fluid, varargin)
            
            model = model@ReservoirModel(G, rock, fluid);
            
            % Typical black oil is disgas / dead oil, but all combinations
            % are supported
            model.vapoil = false;
            model.disgas = true;
           
            % Max increments
            model.drsMaxAbs = inf;
            model.drsMaxRel = inf;
            
            model.useCNVConvergence = true;
            model.toleranceCNV = 1e-3;
            model.toleranceMB = 1e-7;
            model.toleranceWellBHP = 1*barsa;
            model.toleranceWellRate = 1/day;
                        
            % All phases are present
            model.oil = true;
            model.gas = true;
            model.water = true;
            model.saturationVarNames = {'sw', 'so', 'sg'};
            
            model = merge_options(model, varargin{:});
            
            d = model.inputdata;
            if ~isempty(d)
                if isfield(d, 'RUNSPEC')
                    if isfield(d.RUNSPEC, 'VAPOIL')
                        model.vapoil = d.RUNSPEC.VAPOIL;
                    end
                    if isfield(d.RUNSPEC, 'DISGAS')
                        model.disgas = d.RUNSPEC.DISGAS;
                    end
                else
                    error('Unknown dataset format!')
                end
            end
            model = model.setupOperators(G, rock, 'deck', model.inputdata);
        end
        
        function [fn, index] = getVariableField(model, name)
            switch(lower(name))
                case 'rs'
                    fn = 'rs';
                    index = 1;
                case 'rv'
                    fn = 'rv';
                    index = 1;
                otherwise
                    % Basic phases are known to the base class
                    [fn, index] = getVariableField@ReservoirModel(model, name);
            end
        end

        function [convergence, values] = checkConvergence(model, problem, varargin)
            if model.useCNVConvergence
                % Use convergence model similar to commercial simulator
                [conv_cells, v_cells] = CNV_MBConvergence(model, problem);
                [conv_wells, v_wells] = checkWellConvergence(model, problem);
                
                convergence = all(conv_cells) && all(conv_wells);
                values = [v_cells, v_wells];
            else
                % Use strict tolerances on the residual without any 
                % fingerspitzengefuhlen by calling the parent class
                [convergence, values] = checkConvergence@PhysicalModel(model, problem, varargin{:});
            end            
        end
        
        function [problem, state] = getEquations(model, state0, state, dt, drivingForces, varargin)
            [problem, state] = equationsBlackOil(state0, state, model, dt, ...
                            drivingForces, varargin{:});
            
        end
        
        function [state, report] = updateState(model, state, problem, dx, drivingForces)
            saturations = lower(model.saturationVarNames);
            wi = strcmpi(saturations, 'sw');
            oi = strcmpi(saturations, 'so');
            gi = strcmpi(saturations, 'sg');

            vars = problem.primaryVariables;
            removed = false(size(vars));
            if model.disgas || model.vapoil
                % The VO model is a bit complicated, handle this part
                % explicitly.
                state0 = state;
                
                state = model.updateStateFromIncrement(state, dx, problem, 'pressure', model.dpMaxRel, model.dpMaxAbs);
                [vars, ix] = model.stripVars(vars, 'pressure');
                removed(~removed) = removed(~removed) | ix;
                
                % Black oil with dissolution
                so = model.getProp(state, 'so');
                sw = model.getProp(state, 'sw');
                sg = model.getProp(state, 'sg');

                % Magic status flag, see inside for doc
                st = getCellStatusVO(state0, so, sw, sg, model.disgas, model.vapoil);

                dr = model.getIncrement(dx, problem, 'x');
                dsw = model.getIncrement(dx, problem, 'sw');
                % Interpretation of "gas" phase varies from cell to cell, remove
                % everything that isn't sG updates
                dsg = st{3}.*dr - st{2}.*dsw;

                if model.disgas
                    state = model.updateStateFromIncrement(state, st{1}.*dr, problem, ...
                                                           'rs', model.drsMaxRel, model.drsMaxAbs);
                end

                if model.vapoil
                    state = model.updateStateFromIncrement(state, st{2}.*dr, problem, ...
                                                           'rv', model.drsMaxRel, model.drsMaxAbs);
                end

                dso = -(dsg + dsw);

                ds = zeros(numel(so), numel(saturations));
                ds(:, wi) = dsw;
                ds(:, oi) = dso;
                ds(:, gi) = dsg;

                state = model.updateStateFromIncrement(state, ds, problem, 's', model.dsMaxRel, model.dsMaxAbs);
                % We should *NOT* be solving for oil saturation for this to make sense
                assert(~any(strcmpi(vars, 'so')));
                state = computeFlashBlackOil(state, state0, model, st);
                state.s  = bsxfun(@rdivide, state.s, sum(state.s, 2));

                %  We have explicitly dealt with rs/rv properties, remove from list
                %  meant for autoupdate.
                [vars, ix] = model.stripVars(vars, {'sw', 'so', 'sg', 'rs', 'rv', 'x'});
                removed(~removed) = removed(~removed) | ix;

            end
            
            % We may have solved for a bunch of variables already if we had
            % disgas / vapoil enabled, so we remove these from the
            % increment and the linearized problem before passing them onto
            % the generic reservoir update function.
            problem.primaryVariables = vars;
            dx(removed) = [];
        
            % Parent class handles almost everything for us
            [state, report] = updateState@ReservoirModel(model, state, problem, dx, drivingForces);

            % Handle the directly assigned values (i.e. can be deduced directly from
            % the well controls. This is black oil specific.
            W = drivingForces.Wells;
            state.wellSol = assignWellValuesFromControl(model, state.wellSol, W, wi, oi, gi);
        end
    end
end