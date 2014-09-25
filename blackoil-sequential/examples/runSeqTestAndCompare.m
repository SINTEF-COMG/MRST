mrstModule add ad-unittest
% [G, rock, fluid, deck, state] = setupSPE1();
testcase = TestSPE1();
% testcase = TestEGG();

mrstModule add ad-fi deckformat mrst-gui ad-core ad-blackoil blackoil-sequential ad-unittest


model    = testcase.model;
state    = testcase.state0;
schedule = testcase.schedule;
rock     = testcase.rock;
G        = model.G;
state.wellSol = initWellSolAD(schedule.control(1).W, model, state);

schedule.step.val = schedule.step.val(1:10);
schedule.step.control = schedule.step.control(1:10);

%%
solver = NonLinearSolver('enforceResidualDecrease', false, 'useRelaxation', true);

clear pressureModel transportModel
mrstModule add blackoil-sequential

if isa(model, 'TwoPhaseOilWaterModel')
    pressureModel  = PressureOilWaterModel(G, rock, model.fluid);
    transportModel = TransportOilWaterModel(G, rock, model.fluid, 'nonlinearTolerance', 1e-6);
else
    pressureModel  = PressureBlackOilModel(G, rock, model.fluid);
    transportModel = TransportBlackOilModel(G, rock, model.fluid, 'nonlinearTolerance', 5e-3, ...
        'conserveWater', false, 'conserveOil', true, 'conserveGas', true);
end

mrstVerbose on
seqModel = SequentialPressureTransportModel(pressureModel, transportModel);

[ws_split, states_split, report_split] = simulateScheduleAD(state, seqModel, schedule, 'NonLinearSolver', solver);


%% Run the entire schedule
[ws_fi, states_fi, report_fi] = simulateScheduleAD(state, model, schedule);




%% Plot the well solutions and simulator states
% We setup interactive viewers for both well solutions and the reservoir
% states.

time = {report_fi.ReservoirTime, report_split.ReservoirTime};
ws = {ws_fi, ws_split};

plotWellSols(ws, time, 'datasetnames', {'FI', 'sequential'})
%%
for i = 1:2
    if i == 1
        states = states_fi;
        t = 'fully implicit';
    else
        states = states_split;
        t = 'sequential';
    end
    
    figure;
    plotToolbar(G, states)
    plotWell(G, schedule.control(1).W)
    axis tight
    view(-10, 60)
    title(t)
end