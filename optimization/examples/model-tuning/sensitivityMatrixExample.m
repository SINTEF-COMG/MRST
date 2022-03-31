%% Simple script for validation of parameter sensitivities by comparing 
mrstModule add ad-core ad-blackoil ad-props optimization spe10 deckformat coarsegrid

%% Setup simple model
nxyz = [ 50,  50,  1];
Dxyz = [400, 400, 10];
rng(0)
G    = computeGeometry(cartGrid(nxyz, Dxyz));
rock = getSPE10rock(1:nxyz(1), (1:nxyz(2)), 1:nxyz(3));
rock.poro = max(rock.poro, 0.1);
%rock.perm = ones(size(rock.perm))*1*darcy;

% fluid
pRef  = 200*barsa;
fluid = initSimpleADIFluid('phases', 'WO',... 
                           'mu' , [.3, 3]*centi*poise,...
                           'rho', [1014, 859]*kilogram/meter^3, ...
                           'n', [2 2]);
%fluid .krPts  = struct('w', [0 0 1 1], 'ow', [0 0 1 1]);

c = 5e-5/barsa;
p_ref = 200*barsa;
fluid.bO = @(p) exp((p - p_ref)*c);
modelRef = GenericBlackOilModel(G, rock, fluid, 'gas', false);

%% wells/schedule
W = [];
% Injectors (lower-left and upper-right)
[wx, wy] = deal([1, nxyz(1)], [1, nxyz(2)]);
for k  = 1:2
    W = verticalWell(W, G, rock, wx(k), wy(k), 1:nxyz(3), 'Type' , 'rate', ...
                     'Val', 300*meter^3/day, 'Name', sprintf('I%d', k), ...
                     'comp_i', [1 0], 'Sign' , 1);
end
% Producers (upper-left and -right)
[wx, wy] = deal([1, nxyz(1)], [nxyz(2), 1]);
for k  = 1:2
    W = verticalWell(W, G, rock, wx(k), wy(k), 1:nxyz(3), 'Type' , 'bhp', ...
                     'Val', 100*barsa, 'Name', sprintf('P%d', k), ...
                     'comp_i', [1 0], 'Sign' , -1);
end
% Set up 4 control-steps each 150 days
scheduleRef = simpleSchedule(rampupTimesteps(2*year, 30*day, 5), 'W', W);
%schedule = simpleSchedule([1]*day, 'W', W);

%% run reference simulation
stateInitRef = initState(G, W, 200*barsa, [0, 1]); 
% The accuracy in the gradient depend on the acuracy on the CNV tolerance
modelRef.toleranceCNV = 1e-8;
[wsRef, statesRef] = simulateScheduleAD(stateInitRef, modelRef, scheduleRef);

%% make a coarse model and run
p     = partitionCartGrid(modelRef.G.cartDims, [4 4 1]);
model = upscaleModelTPFA(modelRef, p);
model.toleranceCNV = 1e-6;
schedule = upscaleSchedule(model, scheduleRef);

stateInit = upscaleState(model, modelRef, stateInitRef);
[ws0, states0] = simulateScheduleAD(stateInit, model, schedule);

% check well curves
plotWellSols({wsRef, ws0}, schedule.step.val, 'datasetnames', {'Reference', 'Coarse'})

%% parameter options
setup = struct('model', model, 'schedule', schedule, 'state0', stateInit);
nc =  modelRef.G.cells.num;
nf =  numel(modelRef.operators.T);
% transmissibility
parameters{1} = ModelParameter(setup, 'name', 'transmissibility', ...
                                      'type', 'value');
parameters{2} = ModelParameter(setup, 'name', 'conntrans', ...
                                      'type', 'value');                                  
                                                

%% Setup function handle to evaluateMatch
u = getScaledParameterVector(setup, parameters);
% Define weights for objective
weighting =  {'WaterRateWeight',  (300/day)^-1, ...
              'OilRateWeight',    (300/day)^-1, ...
              'BHPWeight',        (500*barsa)^-1};
          
% 1. gradient case - objective is sum of mismatches squared          
obj1 = @(model, states, schedule, statesRef, tt, tstep, state) matchObservedOW(model, states, schedule, statesRef,...
       'computePartials', tt, 'tstep', tstep, weighting{:}, 'state', state, 'from_states', false, 'mismatchSum', true);   
f1 = @(u)evaluateMatch(u, obj1, setup ,parameters,  statesRef, 'enforceBounds', false);     

% 2. sensitivity matrix case - objective computes vector of all mismatches
% accumulate residuals
[nw, nt, ns] = deal(numel(W), 3, numel(schedule.step.val));
% In total there are nw*nt*ns residuals. Rather than computing the Jacobian
% for each residual, we can merge a group of residuals into a single
% residual, e.g., {r_i} -> (sum_i r_i^2)^1/2, thus resulting in a Jacobian
% with fewer rows (but likeliy lead to worse convergence of LM)

% We define the merging of residuals on three levels
% 1. Wells. We assign an integer for each well such that equal integers
% result in merging residuals, e.g., for the four wells here
% [1 2 3 4] : no merging 
% [1 1 1 1] : merge all wells
% [1 1 2 3] : merge wells 1 and 2 but keep wells 3 and 4 seperate 
accumWells = [1 2 3 4]'; % no merging
% 2. Types (oil/water rates and bhp)
accumTypes = [1 2 3]'; % no merging
% 3. Time steps
numSteps = numel(schedule.step.val);
accumSteps = (1:numel(schedule.step.val))'; % no merging
% with the above selection, no merging is performed. In the other extreme, 
% if one sets all entries to 1, all residuals will be merged and the
% LM-method will be equivalent to steepest descent (and perform very
% poorly).

% check that sizes are adequate
assert(numel(accumWells)==nw && numel(accumTypes)==nt && numel(accumSteps)==ns);

accumulateResiduals = struct('wells', accumWells, ...
                             'types', accumTypes, ...
                             'steps', accumSteps);

obj2 = @(model, states, schedule, statesRef, tt, tstep, state) matchObservedOW(model, states, schedule, statesRef,...
       'computePartials', tt, 'tstep', tstep, weighting{:}, 'state', state, 'from_states', false, 'mismatchSum', false, ...
       'accumulateWells', accumWells, 'accumulateTypes', accumTypes);
f2 = @(u)evaluateMatchSummands(u, obj2, setup ,parameters,  statesRef, 'enforceBounds', false, ...
            'accumulateResiduals', accumulateResiduals);       

%% Check gradient in random direction and compare to numerical
% compute (negative) sum of squared mismatches and (negative) gradient
[v1, g] = f1(u);

% compute vector of squared mismatches and Jacobian
[v2, J] = f2(u);

% check that sum of squared v2 matches negative v1
fprintf('Relative sum squared difference: %e\n', norm(sum(v2.^2) + v1)/abs(v1))

% check that both produce the same gradient, i.e 2*J'*v2 = -g
fprintf('Relative gradient difference: %e\n', norm(2*J'*v2 + g)/norm(g))
