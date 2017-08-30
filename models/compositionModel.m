classdef compositionModel < ChemicalModel
    
    
    properties
        inputNames   % Names of variables that are used as inputs
        unknownNames % Names of variables that are used as inputs
        logUnknownNames
        logInputNames % input names with log attached
    end
    
    methods

        function model = compositionModel()
            model = model@ChemicalModel();
        end
        
        function model = validateModel(model)
            model = validateModel@ChemicalModel(model);
            % setup unknownNames
            unknownNames = horzcat(model.CompNames, model.MasterCompNames,model.CombinationNames, model.GasNames, model.SolidNames);
            ind = cellfun(@(name)(strcmpi(name, model.inputNames)), unknownNames, ...
                          'Uniformoutput', false);
            Pind = cellfun(@(x) ~isempty(x) , regexpi(unknownNames, 'psi'), 'Uniformoutput', false);
            
            Pind = cell2mat(Pind');
            ind = cell2mat(ind');
            ind = sum(ind, 2);
            ind = logical(ind) + Pind;
            model.unknownNames = unknownNames(~ind);
            
            
        end

        function [problem, state] = getEquations(model, state0, state, dt, drivingForces, varargin)

            [comps, masterComps, comboComps, gasComps, solidComps] = prepStateForEquations(model, state);

            [eqs, names, types] = equationsCompositionGuess(state, comps, masterComps, comboComps,gasComps, solidComps, model);
            
            primaryVariables = model.unknownNames;
            problem = LinearizedProblem(eqs, types, names, primaryVariables, state, dt);

        end
        
        
        function [comps, masterComps, combinationComps, gasComps, solidComps] = prepStateForEquations(model, ...
                                                              state)
            
            CNames = model.CompNames;
            MCNames = model.MasterCompNames;
            LCNames = model.CombinationNames;
            GNames = model.GasNames;
            SNames = model.SolidNames;
            unknowns = model.unknownNames;
            knowns = model.inputNames;
            
            compInd = cellfun(@(x) isempty(x), regexpi(CNames, 'psi'));
            CNames = CNames(compInd);
            nC = numel(CNames);
            
            uknwnInd = cellfun(@(x) isempty(x), regexpi(unknowns, 'psi'));
            unknowns = unknowns(uknwnInd);
            
            unknownVal = cell(1,numel(unknowns));
            [unknownVal{:}] = model.getProps(state, unknowns{:});
            [unknownVal{:}] = initVariablesADI(unknownVal{:});
            
            knownVal = cell(1,numel(knowns));
            [knownVal{:}] = model.getProps(state, knowns{:});
            
            comps = cell(1,nC);
            for i = 1 : nC
                cInd = strcmpi(unknowns, CNames{i});
                if any(cInd)
                    comps{i} = unknownVal{cInd};
                end
                cInd = strcmpi(knowns, CNames{i});
                if any(cInd)
                    comps{i} = knownVal{cInd};
                end
            end
            
            masterComps = cell(1,model.nMC);
            for i = 1 : model.nMC
                mcInd = strcmpi(unknowns, MCNames{i});
                if any(mcInd)
                    masterComps{i} = unknownVal{mcInd};
                end
                mcInd = strcmpi(knowns, MCNames{i});
                if any(mcInd)
                    masterComps{i} = knownVal{mcInd};
                end
            end
           
           combinationComps = cell(1,model.nLC);
            for i = 1 : model.nLC
                mcInd = strcmpi(unknowns, LCNames{i});
                if any(mcInd)
                    combinationComps{i} = unknownVal{mcInd};
                end
                mcInd = strcmpi(knowns, LCNames{i});
                if any(mcInd)
                    combinationComps{i} = knownVal{mcInd};
                end
            end
            
            
            gasComps = cell(1,model.nG);
            for i = 1 : model.nG
                gInd = strcmpi(unknowns, GNames{i});
                if any(gInd)
                    gasComps{i} = unknownVal{gInd};
                end
                gInd = strcmpi(knowns, GNames{i});
                if any(gInd)
                    gasComps{i} = knownVal{gInd};
                end
            end
           
            solidComps = cell(1,model.nS);
            for i = 1 : model.nS
                sInd = strcmpi(unknowns, SNames{i});
                if any(sInd)
                    solidComps{i} = unknownVal{sInd};
                end
                sInd = strcmpi(knowns, SNames{i});
                if any(sInd)
                    solidComps{i} = knownVal{sInd};
                end
            end
        end
        
        function [state, failure, report] = solveChemicalState(model, inputstate)
        % inputstate contains the input and the initial guess.

            inputstate = model.validateState(inputstate); % in particular,
                                                          % updates the log
                                                          % variables if necessary.

            solver = NonLinearSolver('maxIterations', 2);
            dt = 0; % dummy timestep
            drivingForces = []; % drivingForces;
            inputstate0 = inputstate;

            [state, failure, report] = solveMinistep(solver, model, inputstate, ...
                                                     inputstate0, dt, ...
                                                     drivingForces);

        end
        
        function [state, report] = updateState(model, state, problem, dx, drivingForces) %#ok
        % Update state based on Newton increments
            [state, report] = updateState@PhysicalModel(model, state, problem, ...
                                                        dx, drivingForces);
            
            len = cellfun(@(x) length(x), problem.primaryVariables);
            [~,sortInd] = sort(len(:),1, 'ascend');
            pVar = problem.primaryVariables(sortInd);
            
            for i = 1 : numel(pVar)
                p = pVar{i};
                if ismember(p, model.CombinationNames)
                    state = model.capProperty(state, p, -2.5*mol/litre, 2.5*mol/litre);
                elseif ismember(p, [model.GasNames model.SolidNames])
                    state = model.capProperty(state, p, 1e-30, 1);
                else
                    state = model.capProperty(state, p, eps, 2.5*mol/litre);
                end
            end
            state = model.syncLog(state);
        end
        
        function [state, report] = updateAfterConvergence(model, state0, state, dt, drivingForces) %#ok
        % solve for the electrostatics
        
            state = model.syncLog(state);

        
            report = [];
        end
    
    end

end
    