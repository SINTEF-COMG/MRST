classdef GenericSurfactantPolymerModel < ThreePhaseSurfactantPolymerModel & ExtendedReservoirModel
    properties
        toleranceEOR = 1e-3;
    end
    
    methods
        function model = GenericSurfactantPolymerModel(G, rock, fluid, deck, varargin)
            model = model@ThreePhaseSurfactantPolymerModel(G, rock, fluid, deck, varargin{:});
            model.OutputStateFunctions = {'ComponentTotalMass'};
        end

        function [problem, state] = getEquations(model, state0, state, dt, drivingForces, varargin)
            [problem, state] = getEquations@PhysicalModel(model, state0, state, dt, drivingForces, varargin{:});
        end

        function [vars, names, origin] = getPrimaryVariables(model, state)
            [vars, names, origin] = getPrimaryVariables@ThreePhaseBlackOilModel(model, state);
            current = class(model);
            
            eor_names = {};
            if model.polymer
                eor_names{end+1} = 'polymer';
            end
            
            if model.surfactant
                eor_names{end+1} = 'surfactant';
            end
            [eor_vars, eor_origin] = deal(cell(1, numel(eor_names)));
            [eor_vars{:}] = model.getProps(state, eor_names{:});
            [eor_origin{:}] = deal(current);
            
            isRes = strcmp(origin, current);
            
            vars = [vars(isRes), eor_vars, vars(~isRes)];
            names = [names(isRes), eor_names, names(~isRes)];
            origin = [origin(isRes), eor_origin, origin(~isRes)];
        end
        
        function [eqs, names, types, state] = getModelEquations(model, state0, state, dt, drivingForces)
            [eqs, flux, names, types] = model.FluxDiscretization.componentConservationEquations(model, state, state0, dt);
            src = model.FacilityModel.getComponentSources(state);

            % Assemble equations and add in sources
            for i = 1:numel(eqs)
                if ~isempty(src.cells)
                    eqs{i}(src.cells) = eqs{i}(src.cells) - src.value{i};
                end
                eqs{i} = model.operators.AccDiv(eqs{i}, flux{i});
            end
            % Get facility equations
            [weqs, wnames, wtypes, state] = model.FacilityModel.getModelEquations(state0, state, dt, drivingForces);
            eqs = [eqs, weqs];
            names = [names, wnames];
            types = [types, wtypes];
        end

        function names = getComponentNames(model)
            names = cellfun(@(x) x.name, model.Components, 'UniformOutput', false);
        end

        function [state, report] = updateState(model, state, problem, dx, forces)
            [state, report] = updateState@ThreePhaseSurfactantPolymerModel(model, state, problem, dx, forces);
            if ~isempty(model.FacilityModel)
                state = model.FacilityModel.applyWellLimits(state);
            end
        end

        function model = validateModel(model, varargin)
            % Validate model.
            %
            % SEE ALSO:
            %   :meth:`ad_core.models.PhysicalModel.validateModel`
            if isempty(model.FacilityModel) || ~isa(model.FacilityModel, 'ExtendedFacilityModel')
                model.FacilityModel = ExtendedFacilityModel(model);
            end
            if isempty(model.Components)
                nph = model.getNumberOfPhases();
                names = model.getPhaseNames();
                disgas = model.disgas;
                vapoil = model.vapoil;
                hasPoly = model.polymer;
                hasSurf = model.surfactant;
                model.Components = cell(1, nph+hasPoly+hasSurf);
                for ph = 1:nph
                    switch names(ph)
                        case 'W'
                            c = ImmiscibleComponent('water', ph);
                        case 'O'
                            if disgas || vapoil
                                c = OilComponent('oil', ph, disgas, vapoil);
                            else
                                c = ImmiscibleComponent('oil', ph);
                            end
                        case 'G'
                            if disgas || vapoil
                                c = GasComponent('gas', ph, disgas, vapoil);
                            else
                                c = ImmiscibleComponent('gas', ph);
                            end
                        otherwise
                            error('Unknown phase');
                    end
                    model.Components{ph} = c;
                end
                index = nph + 1;
                if hasPoly
                    c = PolymerComponent();
                    model.Components{index} = c;
                    index = index + 1;
                end
                if hasSurf
                    % Not implemented - fill me in
                    c = SurfactantComponent();
                    model.Components{index} = c;
                    model.operators.veloc = ...
                        computeVelocTPFA(model.G, model.operators.internalConn);
                    model.operators.sqVeloc = ...
                        computeSqVelocTPFA(model.G, model.operators.internalConn);
                end
            end
            model = validateModel@ThreePhaseSurfactantPolymerModel(model, varargin{:});
        end

        function [state, report] = updateAfterConvergence(model, state0, state, dt, drivingForces)
            [state, report] = updateAfterConvergence@ThreePhaseSurfactantPolymerModel(model, state0, state, dt, drivingForces);
            if model.outputFluxes
                state_flow = model.FluxDiscretization.buildFlowState(model, state, state0, dt);
                f = model.getProp(state_flow, 'PhaseFlux');
                nph = numel(f);
                state.flux = zeros(model.G.faces.num, nph);
                state.flux(model.operators.internalConn, :) = [f{:}];
            end
        end
        
        function [values, tolerances, names] = getConvergenceValues(model, problem, varargin)
            [values, tolerances, names] = getConvergenceValues@ThreePhaseSurfactantPolymerModel(model, problem, varargin{:});
            % Polymer/Surfactant: Scale the convergence criterion to be
            % dimensionless. Since we have accumulation terms on the form:
            %    pv * rhoW * c * sW / dt
            % we can apply the scaling
            %    dt / (pv * rhoW * c_max)
            % to get something which has no units and can be compared
            % against our tolerance for EOR components.
            dt = problem.dt;
            pv = model.operators.pv;
            rhoS = model.fluid.rhoWS(1);
            cnames = {'polymer', 'surfactant'};
            cf     = {'cpmax', 'csmax'};
            for i = 1:numel(cnames)
                cn = cnames{i};
                isEOR = strcmpi(names, cn);
                if any(isEOR)
                    if isfield(model.fluid, cf{i})
                        cmax = model.fluid.(cf{i});
                    else
                        cmax = 1;
                    end
                    isEq = strcmp(problem.equationNames, cn);
                    eq = value(problem.equations{isEq});
                    scale = dt./(pv.*cmax.*rhoS);
                    values(isEOR) = max(abs(eq.*scale));
                    tolerances(isEOR) = model.toleranceEOR;
                end
            end
        end
    end
end