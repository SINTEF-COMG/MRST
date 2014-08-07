classdef NonLinearSolver < handle
%Generalized Newton-like nonlinear solver
%
% SYNOPSIS:
%   solver = NonLinearSolver()
%
%   solver = NonLinearSolver('maxIterations', 5)
%
% DESCRIPTION:
%   The NonLinearSolver class is a general non-linear solver based on
%   Newton's method. It is capable of timestep selection and cutting based
%   on convergence rates and can be extended via subclassing or modular
%   linear solvers and timestep classes.
%
%   Convergence is handled by the PhysicalModel class. The NonLinearSolver
%   simply responds based on what the model reports in terms of convergence
%   to ensure some level of encapsulation.
%
% REQUIRED PARAMETERS:
%   None.
%
% OPTIONAL PARAMETERS (supplied in 'key'/value pairs ('pn'/pv ...)):
%   Documented in methods section.
%
% RETURNS:
%   A NonLinearSolver class instance ready for use. 
%
% SEE ALSO:
%   simulateScheduleAD, LinearSolverAD, SimpleTimeStepSelector

%{
Copyright 2009-2014 SINTEF ICT, Applied Mathematics.

This file is part of The MATLAB Reservoir Simulation Toolbox (MRST).

MRST is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

MRST is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with MRST.  If not, see <http://www.gnu.org/licenses/>.
%}

    properties
        % The max number of iterations during a ministep.
        maxIterations
        % The maximum number of timesteps allowed due to cutting of the
        % timestep when faced with convergence issues.
        maxSubsteps
        % The solver used to solve the linearized problems during the
        % simulation.
        LinearSolver
        % Verbose flag used to get extra output during simulation.
        verbose
        % Subclass of SimpleTimeStepSelector used to select timesteps
        % during simulation. By default no dynamic timestepping will be
        % enabled.
        timeStepSelector
        
        % Boolean indicating if Newton increments should be relaxed.
        useRelaxation
        % Relaxation parameter between 0 and 1. This is modified
        % dynamically if useRelaxation is on, and should in general not be
        % modified unless you know what you are doing.
        relaxationParameter
        % Either 'dampen', 'sor' or 'none'
        % For dampen, where w = relaxationParameter.
        %       x_new = x_old + dx*w
        % For successive over-relaxation (SOR)
        %       x_new = x_old + dx*w + dx_prev*(1-w)
        relaxationType
        % INternal bookkeeping.
        previousIncrement

        % If error on failure is not enabled, the solver will return even
        % though it did not converge. May be useful for debugging. Results
        % should not be relied upon if this is enabled.
        errorOnFailure
    end
    
    methods
        function solver = NonLinearSolver(varargin)            
            solver.maxIterations = 25;
            solver.verbose       = mrstVerbose();
            solver.maxSubsteps   = 32;
            solver.LinearSolver  = [];
            
            solver.relaxationParameter = 1;
            solver.relaxationType = 'dampen';
            solver.useRelaxation = false;
            
            solver.errorOnFailure = true;
            
            solver = merge_options(solver, varargin{:});
            
            if isempty(solver.LinearSolver)
                solver.LinearSolver = BackslashSolverAD();
            end
            
            if isempty(solver.timeStepSelector)
                solver.timeStepSelector = SimpleTimeStepSelector();
            end
        end
        
        function [state, report, ministates] = solveTimestep(solver, state0, dT, model, varargin)
            % Solve a timestep for a non-linear system using one or more substeps
            drivingForces = struct('Wells', [],...
                                   'bc',    [],...
                                   'src',   [],...
                                   'controlId', nan);
            
            drivingForces = merge_options(drivingForces, varargin{:});
            
            
            converged = false;
            done = false;
            
            dt = dT;
            
            % Number of nonlinear iterations total
            itCount = 0;
            % Number of ministeps due to cutting 
            ministepNo = 1;
            % Number of steps
            stepCount = 0;
            % Number of accepted steps
            acceptCount = 0;
            
            t_local = 0;
            
            isFinalMinistep = false;
            state0_inner = state0;
            
            
            wantMinistates = nargout > 2;
            [reports, ministates] = deal(cell(solver.maxSubsteps, 1));
            
            state = state0;
            
            % Let the step selector know that we are at start of timestep
            % and what the current driving forces are
            stepsel = solver.timeStepSelector;
            stepsel.newControlStep(drivingForces);
            
            while ~done
                dt = stepsel.pickTimestep(dt, model, solver);
                
                if t_local + dt >= dT
                    % Ensure that we hit report time
                    isFinalMinistep = true;
                    dt = dT - t_local;
                end
                [state, nonlinearReports, converged, its] = ...
                        solveMinistep(solver, model, state, state0_inner, dt, drivingForces);
                
                % Store timestep info
                clear tmp;
                tmp.NonlinearReport = nonlinearReports;
                tmp.LocalTime = t_local + dt; 
                tmp.Converged = converged;
                tmp.Timestep = dt;
                tmp.Iterations = its;
                
                reports{end+1} = tmp; %#ok 
                stepsel.storeTimestep(tmp);
                
                % Keep total itcount so we know how much time we are
                % wasting
                itCount = itCount + its;
                stepCount = stepCount + 1;
                if converged
                    t_local = t_local + dt;
                    state0_inner = state;
                    acceptCount = acceptCount + 1;
                    
                    if wantMinistates
                        % Output each substep
                        nm = numel(ministates);
                        if nm < acceptCount
                            tmp = cell(nm*2, 1);
                            tmp(1:nm) = ministates;
                            ministates = tmp;
                            clear tmp
                        end
                        ministates{acceptCount} = state;
                    end
                else
                    state = state0_inner;
                    % Beat timestep with a hammer
                    warning('Solver did not converge, cutting timestep')
                    ministepNo = 2*ministepNo;
                    dt = dt/2;
                    if ministepNo > solver.maxSubsteps
                        msg = 'Did not find a solution. Reached maximum amount of substeps';
                        if solver.errorOnFailure
                            error(msg);
                        else
                            warning(msg);
                            converged = false;
                            break;
                        end
                    end
                    isFinalMinistep = false;
                end
                done = isFinalMinistep && converged;
            end
            dispif(solver.verbose, ...
                'Solved timestep with %d accepted ministeps (%d rejected, %d total iterations)\n',...
                acceptCount, stepCount - acceptCount, itCount);
            
            % Truncate reports from step functions
            reports = reports(~cellfun(@isempty, reports));
            report = struct('Iterations',       itCount,...
                            'Converged',        converged,...
                            'MinistepCount', 	ministepNo);
            % Add seperately because struct constructor interprets cell
            % arrays as repeated structs.
            report.StepReports = reports;
            if wantMinistates
                ministates = ministates(~cellfun(@isempty, ministates));
            end
        end
        
        function dx = stabilizeNewtonIncrements(solver, problem, dx)
            % Attempt to stabilize newton increment
            dx_prev = solver.previousIncrement;
            
            w = solver.relaxationParameter;
            if w == 1
                return
            end
            
            switch(lower(solver.relaxationType))
                case 'dampen'
                    for i = 1:numel(dx)
                        dx{i} = dx{i}*w;
                    end
                case 'sor'
                    if isempty(dx_prev)
                        return
                    end
                    for i = 1:numel(dx)
                        dx{i} = dx{i}*w + (1-w)*dx_prev{i};
                    end
                case 'none'
                    
                otherwise
                    error('Unknown relaxationType: Valid options are ''dampen'', ''none'' or ''sor''');
            end
            solver.previousIncrement = dx;
        end
    end
end

function [state, reports, converged, its] = solveMinistep(solver, model, state, state0, dt, drivingForces)
    % Attempt to solve a single mini timestep. Detect oscillations.
    reports = cell(solver.maxIterations, 1);
    omega0 = solver.relaxationParameter;
    
    r = [];
    for i = 1:solver.maxIterations
        [state, stepReport] = ...
            model.stepFunction(state, state0, dt, drivingForces, ...
                               solver.LinearSolver, solver, 'iteration', i);
        if i ~= solver.maxIterations
            converged  = stepReport.Converged;
        else
            % Final iteration, we must check if the previous solve resulted
            % in convergence
            converged = model.checkConvergence(problem);
        end
        if converged
            break
        end
        reports{i} = stepReport;
        
        
        if i > 1 && solver.useRelaxation
            % Check relative improvement
            improvement = (r_prev - stepReport.Residuals)./r_prev;
            % Remove NaN / inf due to converged / not active vars
            improvement = improvement(isfinite(improvement));
            r = [r; sum(improvement)]; %#ok
            if i > 3 && sum(sign(r(end-2:end))) > 0
                solver.relaxationParameter = max(solver.relaxationParameter - 0.1, .5);
            else
                solver.relaxationParameter = min(solver.relaxationParameter + 0.1, 1);
            end
        end
        r_prev = stepReport.Residuals;
    end
    % If we converged, the last step did not solve anything
    its = i - converged;
    reports = reports(~cellfun(@isempty, reports));
    solver.relaxationParameter = omega0;
    if converged
        state = model.updateAfterConvergence(state0, state, drivingForces);
    end
end
