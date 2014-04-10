clear
mrstModule add ad-fi deckformat mrst-gui

% Read and process file.
current_dir = fileparts(mfilename('fullpath'));
fn    = fullfile(current_dir, 'odeh_adi.data');

deck = readEclipseDeck(fn);

% The deck is given in field units, MRST uses metric.
deck = convertDeckUnits(deck);

G = initEclipseGrid(deck);
G = computeGeometry(G);

rock  = initEclipseRock(deck);
rock  = compressRock(rock, G.cells.indexMap);

% Create a special ADI fluid which can produce differentiated fluid
% properties.
fluid = initDeckADIFluid(deck);

% The case includes gravity
gravity on

%%
% The initial state is a pressure field that is constant in each layer, a
% uniform mixture of water (Sw=0.12) and oil (So=0.88) with no initial free
% gas (Sg=0.0) and a constant dissolved gas/oil ratio ("Rs") throughout the
% model.
%
% The pressure and Rs values are derived through external means.
clear prod
[k, k] = ind2sub([prod(G.cartDims(1:2)), G.cartDims(3)], ...
                  G.cells.indexMap);  %#ok

p0    = [ 329.7832774859256 ; ...  % Top layer
          330.2313357125603 ; ...  % Middle layer
          330.9483500720813 ];     % Bottom layer

p0    = convertFrom(p0(k), barsa);
s0    = repmat([ 0.12, 0.88, 0.0 ], [G.cells.num, 1]);
rs0   = repmat( 226.1966570852417 , [G.cells.num, 1]);
rv0   = 0; % dry gas

state = struct('s', s0, 'rs', rs0, 'rv', rv0, 'pressure', p0);   clear k p0 s0 rs0
schedule = deck.SCHEDULE;


%% Initialize schedule and system before solving for all timesteps


system = initADISystem(deck, G, rock, fluid, 'cpr', false);
timer = tic;
[wellSols states iter] = runScheduleADI(state, G, rock, system, schedule);
toc(timer)
%%

W = processWellsLocal(G, rock, schedule.control(1), ...
                                 'Verbose', false, ...
                                 'DepthReorder', false);
schedule.control.W = W;

clear boModel
clear nonlinear

boModel = threePhaseBlackOilModel(G, rock, fluid, 'deck', deck);

% nonlinear = nonlinearSolver();
% [state, status] = nonlinear.solveTimestep(state, 1*day, boModel)


[wellSols, states] = runScheduleRefactor(state, boModel, schedule)