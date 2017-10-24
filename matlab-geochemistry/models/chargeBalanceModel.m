classdef chargeBalanceModel < ChemicalInputModel
    
    
    properties
        CVC         % charge variation component
    end
    
    methods

        function model = chargeBalanceModel()
            model = model@ChemicalInputModel();
            model.CVC = [];
        end
        

        function [problem, state] = getEquations(model, state0, state, dt, drivingForces, varargin)
            
            if ~isfield(state, 'CVC')
            	nCells = size(state.elements,1);
                state.CVC = eps*ones(nCells,1);
            end
            
            [unknowns, components, masterComponents, combinationComponents,...
                 partialPressures, saturationIndiciess, surfaceAcitivityCoefficients, CVC] = prepStateForEquations(model, state);

            [eqs, names, types] = equationsChargeBalance(model, state, components, masterComponents, combinationComponents,...
                 partialPressures, saturationIndiciess, surfaceAcitivityCoefficients, CVC);
            
            problem = LinearizedProblem(eqs, types, names, unknowns, state, dt);

        end
        
        
        function [unknowns, components, masterComponents, combinationComponents,...
                 partialPressures, saturationIndiciess, surfaceAcitivityCoefficients,CVC] = prepStateForEquations(model, ...
                                                              state)
            
            CNames = model.logSpeciesNames;
            MCNames = model.logElementNames;
            LCNames = model.combinationNames;
            GNames = model.logGasNames;
            SNames = model.logSolidNames;
            SPNames = model.logSurfaceActivityCoefficientNames;
            
            unknowns = model.unknownNames;
            knowns = model.inputNames;
            
            unknowns = addLogToNames(unknowns);
            knowns = addLogToNames(knowns);
            
            for i = 1 : model.nLC
                unknowns = regexprep(unknowns, ['log'  LCNames{i}],  LCNames{i});
                knowns = regexprep(knowns, ['log'  LCNames{i}],  LCNames{i});
            end
            
            unknownVal = cell(1,numel(unknowns));
            [unknownVal{:}] = model.getProps(state, unknowns{:});
            [unknownVal{:}] = initVariablesADI(unknownVal{:});
            
            knownVal = cell(1,numel(knowns));
            [knownVal{:}] = model.getProps(state, knowns{:});
            

            components           = distributeVariable( CNames, knowns, unknowns, knownVal, unknownVal );
            masterComponents     = distributeVariable( MCNames, knowns, unknowns, knownVal, unknownVal );
            combinationComponents   = distributeVariable( LCNames, knowns, unknowns, knownVal, unknownVal );
            partialPressures   = distributeVariable( GNames, knowns, unknowns, knownVal, unknownVal );
            saturationIndiciess = distributeVariable( SNames, knowns, unknowns, knownVal, unknownVal );
            surfaceAcitivityCoefficients = distributeVariable( SPNames, knowns, unknowns, knownVal, unknownVal );

            cvcInd = strcmpi(unknowns, 'CVC');
            CVC = unknownVal{cvcInd}; 
            
        end
        
        function [state, failure, report] = solveChemicalState(model, inputstate)
        % inputstate contains the input and the initial guess.

            % grab the names of unknowns                                              
            unknownNames = horzcat(model.speciesNames, model.elementNames,model.combinationNames, 'CVC', model.solidNames, model.gasNames, model.surfaceActivityCoefficientNames);
            ind = ismember(unknownNames, model.inputNames);
            model.unknownNames = unknownNames(~ind);
            
            solver = NonLinearSolver(); 
            
            solver.maxIterations= model.nonLinearMaxIterations;
            solver.minIterations= model.nonLinearMinIterations;
            solver.LinearSolver.tolerance = model.linearTolerance;
            solver.LinearSolver.maxIterations = model.linearMaxIterations;
            
            dt = 0; % dummy timestep
            drivingForces = []; % drivingForces;
            inputstate0 = inputstate;

            
            [state, failure, report] = solveMinistep(solver, model, inputstate, ...
                                                     inputstate0, dt, ...
                                                     drivingForces);

        end
        
        function [state, report] = updateState(model, state, problem, dx, drivingForces) %#ok
        % Update state based on Newton increments
            state0 = state;
            [state, report] = updateState@PhysicalModel(model, state, problem, ...
                                                        dx, drivingForces);
        
            state = model.syncFromLog(state);                                       
            state = updateChemicalModel(model, problem, state, state0 );
            state = model.syncLog(state);
             
                                                   
        end
        
        function [state, report] = updateAfterConvergence(model, state0, state, dt, drivingForces) %#ok
        % solve for the electrostatics
        
            CVC = model.getProp(state, 'CVC');
            MCval = model.getProp(state, model.CVC);
            
            warningText = ['Charge balance could not be acheived with given constraint on ' model.CVC ' increase the value if reasonable.'];
            
            if ~all(abs(CVC) <= 10*MCval),
                warning(warningText);
            end
            
            state = model.setProp(state, model.CVC, MCval + CVC);
            assert(all((MCval + CVC) > 0), warningText);
           
            state= rmfield(state, 'CVC');
            state = model.syncLog(state);
        
        
            report = [];
        end
    
    end

end
    