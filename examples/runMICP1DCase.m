%% Basic workflow example for the MICP model
%
% This example aims to show complete workflow for creating, running, and
% analyzing a 1D-flow system using the MICP mathematical model in both
% MATLAB and/or GNU Octave.
%
% For details on the MICP model, see
% Landa-Marbán, D., Tveit, S., Kumar, K., Gasda, S.E., 2021. Practical 
% approaches to study microbially induced calcite precipitation at the 
% field scale. Int. J. Greenh. Gas Control 106, 103256. 
% https://doi.org/10.1016/j.ijggc.2021.103256

% Required modules
mrstModule add ad-blackoil ad-core ad-micp

%% Reservoir geometry/properties and model parameters
%
% The domain has a length of L m and the grid is discretized in equal
% size elements of dx m in the first l m (except on the left boundary 
% where an injection well will be placed) where the region of interest is
% located, and after the grid becomes coarser towards the right boundary
% (the grid is given as L x 1 m x 1 m). 

% Grid
L = 75;               % Aquifer length, m
l = 25;               % Region where MICP processes are more relevant, m
dw = 0.5;             % Size of the element for the well, m
dl = 0.25;            % Size of the elements inside l, m
% The values inside the exponent in the following line set how the coarsing
% of the grid will be (they should be changed if the above values change).
X = [0 dw dw + dl : dl : l  L * exp(-1.05 : 0.05 : 0)];
G = tensorGrid(X, [0 1], [0 1]);
G = computeGeometry(G);
C = ones(G.cells.num, 1);

% Rock properties
K0 = 1e-12 * C;               % Aquifer permeability, m^2
porosity = 0.2;               % Aquifer porosity, [-]
rock = makeRock(G, K0, porosity);

% Fluid properties
fluid.muw = 2.535e-4;        % Water viscocity, Pa s
fluid.bW = @(p) 0 * p + 1;   % Water formation volume factor, [-]
fluid.rhoWS = 1045;          % Water density, kg/m^3

% Remaining model parameters (we put them on the fluid structure)
fluid.rho_b = 35;            % Density (biofilm), kg/m^3
fluid.rho_c = 2710;          % Density (calcite), kg/m^3
fluid.k_str = 2.6e-10;       % Detachment rate, m/(Pa s)
fluid.diffm = 2.1e-9;        % Diffusion coefficient (microbes), m^2/s
fluid.diffo = 2.32e-9;       % Diffusion coefficient (oxygen), m^2/s
fluid.diffu = 1.38e-9;       % Diffusion coefficient (urea), m^2/s
fluid.alphaL = 1e-3;         % Disperison coefficient (longitudinal), m
fluid.alphaT = 4e-4;         % Disperison coefficient (transverse), m
fluid.eta = 3;               % Fitting factor, [-]
fluid.k_o = 2e-5;            % Half-velocity constant (oxygen), kg/m^3
fluid.k_u = 21.3;            % Half-velocity constant (urea), kg/m^3
fluid.mu = 4.17e-5;          % Maximum specific growth rate, 1/s
fluid.mu_u = 0.0161;         % Maximum rate of urease utilization, 1/s
fluid.k_a = 8.51e-7;         % Microbial attachment rate, 1/s
fluid.k_d = 3.18e-7;         % Microbial death rate, 1/s
fluid.Y = 0.5;               % Yield growth coefficient, [-]
fluid.Yuc = 1.67;            % Yield coeccifient (calcite/urea), [-]
fluid.F = 0.5;               % Oxygen consumption factor, [-]
fluid.crit = 0.1;            % Critical porosity, [-]
fluid.kmin = 1e-20;          % Minimum permeability, m^2
fluid.cells = C;             % Array with all cells, [-]
fluid.ptol = 1e-4;           % Porosity tolerance to stop the simulation

% Porosity-permeability relationship
fluid.K = @(poro) (K0 .* ((poro - fluid.crit) / (porosity - fluid.crit))...
               .^ fluid.eta + fluid.kmin) .* K0 ./ (K0 + fluid.kmin) .* ...
                  (poro > fluid.crit) + fluid.kmin .* (poro <= fluid.crit);

% The two following lines are not really used in these simulations since
% the current MICP implementation only considers single-phase flow (it is
% possible to extend to two-phase flow), but since the implementation is
% based on the 'equationsOilWaterPolymer' script (two-phase flow), they are
% required to avoid errors.
fluid.bO   = fluid.bW;
fluid.rhoOS = fluid.rhoWS;

%% Define the injection well, outflow boundary, and simulation schedule
%
% The components are injected from the left side of the aquifer.

% Create well
Q = 2 / day;    % Injection rate, m^3/s
r = 0.15;       % Well radius, m

% Injector
W = addWell([], G, rock, 1, 'Type', 'rate', 'Comp_i', [1, 0], ...
                                                    'Val', Q, 'Radius', r);
W.m = 0.01;  % Initial injected microbial concentration, kg/m^3
W.o = 0;
W.u = 0;

% If the injection well is on the boundary, the well cells are save in G
% to correct the velocity field when computing dispersion/detachment (see
% the getDispersionAnddpWMICP script)
G.injectionwellonboundary = 1;
G.cellsinjectionwell = 1;

% On the right side of the aquifer we set a constant pressure to model an
% open boundary. 
f = boundaryFaces(G);
f = f(abs(G.faces.normals(f, 1)) > 0 & G.faces.centroids(f, 1) > ...
                                                               X(end - 1));
bc = addBC([], f, 'pressure', atm, 'sat', [0 0]);
bc.m = zeros(size(bc.sat, 1), 1);
bc.o = zeros(size(bc.sat, 1), 1);
bc.u = zeros(size(bc.sat, 1), 1);
bc.b = zeros(size(bc.sat, 1), 1);
bc.c = zeros(size(bc.sat, 1), 1);

% Setup some schedule. Here we use two different time steps, one for when
% the well is active and a larger one when the well is shut. In this 
% example the total time of the well active is 120 h and the total time for
% simulation is 300 h.  
dt_on = 20 * minute;
dt_off = hour;
nt = 120 * hour / dt_on + (300 - 120) * hour / dt_off;
timesteps = repmat(dt_on, nt, 1);

% Well different rates and times
N = 8; % Number of injection changes
M = zeros(N + 1, 5); % The entries per row are: time, rate, m, o, and u.
M(1, 1) = 20 * hour / dt_on;              % Time of microbial injection, h
M(1, 2) = Q;                              % Well is on, m^3/s
M(2, 1) = M(1, 1) + 20 * hour / dt_on;    % Time of water injection, h
M(2, 2) = 0;                              % Well is closed
M(3, 1) = M(2, 1) + 100 * hour / dt_off;  % Time of closing of the well, h
M(3, 2) = Q;                              % Well is on, m^3/s
M(3, 4) = 0.04;                           % Oxygen concentration, kg/m^3
M(4, 1) = M(3, 1) + 20 * hour / dt_on;    % Time of oxygen injection, h
M(4, 2) = Q;                              % Well is on, m^3/s
M(5, 1) = M(4, 1) + 20 * hour / dt_on;    % Time of water injection, h
M(5, 2) = 0;                              % Well is closed
M(6, 1) = M(5, 1) + 50 * hour / dt_off;   % Time of closing of the well, h
M(6, 2) = Q;                              % Well is on, m^3/s
M(6, 5) = 60;                             % Urea concentration, kg/m^3
M(7, 1) = M(6, 1) + 20 * hour / dt_on;    % Time of urea injection, h
M(7, 2) = Q;                              % Well is on, m^3/s
M(8, 1) = M(7, 1) + 20 * hour / dt_on;    % Starting time for
M(8, 2) = 0;                              % Well is closed
M(9, 1) = M(8, 1) + 30 * hour / dt_on;    % Time left for the simulation, h

% For making the schedule, we first call the 'simpleSchedule' function and
% after we edit the different entries using the M matrix containing the 
% injection strategy.
schedule = simpleSchedule(timesteps, 'W', W, 'bc', bc);
for i = 1 : N
    schedule.control(i + 1) = schedule.control(i);
    schedule.step.control(M(i, 1) : end) = i + 1;
    schedule.step.val(M(i, 1) : end) = (M(i, 2) == 0) * dt_off + ...
                                                     (M(i, 2) > 0) * dt_on;
    schedule.control(i + 1).W.val = M(i, 2);
    schedule.control(i + 1).W.m = M(i, 3);
    schedule.control(i + 1).W.o = M(i, 4);
    schedule.control(i + 1).W.u = M(i, 5);
end

% We store the maximum injected oxygen and urea concentrations in the fluid
% structure. They are use for the dynamical plotting of the solution (see
% 'getPlotAfterStepMICP') and so that the computed oxygen and urea values 
% are within these during the solution step (see 'MICPModel').
fluid.Comax = max(M(:, 4));             
fluid.Cumax = max(M(:, 5));               

%% Set up simulation model
%
% We remark that originally the implementation of this MICP model was based
% on the polymer model in the ad-eor module; then the different model 
% property values are given as in that model. Thus, one can change here
% the default properties after calling the MICPModel function, e.g., here
% we set stricter values for the model tolerances. 

% Model
model = MICPModel(G, rock, fluid);
model.toleranceMB = 1e-15;
model.nonlinearTolerance = 1e-12;

%% Set up solver

solver = getNonLinearSolver(model);

%% Define initial state

% Initially, the only phase is water without dissolved components (one can
% set different initial conditions, e.g., some initial biofilm).
state0 = initState(G, W, atm, [1, 0]);
state0.m = zeros(G.cells.num, 1);
state0.o = zeros(G.cells.num, 1);
state0.u = zeros(G.cells.num, 1);
state0.b = zeros(G.cells.num, 1);
state0.c = zeros(G.cells.num, 1);

%% Simulate 1DCase
%
% If MATLAB is used, we use the getPlotAfterStepMICP function to visualize
% the results at each time step. 

% Simulate case (GNU Octave/MATLAB)
if exist('OCTAVE_VERSION', 'builtin') ~= 0
    ok = 'true';
    % Currently the simulator stops if clogging has been reached in any of 
    % the cells (i.e., porosity-biofilm-calcite<fluid.ptol). In this model
    % a permebaility-porosity relatonship is used where a minimum 
    % permeability value is reached if porosity-biofilm-calcite<fluid.crit.
    fn = checkCloggingMICP(ok);
else
    % The two last entries in the 'getPlotAfterStepMICP' function are the
    % azimuth and elevation angles for view of the current axes while
    % visualizing the solution (you could try with 340, 20).
    fn = getPlotAfterStepMICP(state0, model, 0, 270);
end
[~, states] = simulateScheduleAD(state0, model, schedule, ...
                             'NonLinearSolver', solver, 'afterStepFn', fn);

%% Process the data
% If Octave is used, then the results are printed in vtk format to be
% visualize in Paraview and the 'return' command is executed as currently
% it is not possible to run 'plotToolbar' in Octave.

% Write the results to be read in ParaView (GNU Octave)
if exist('OCTAVE_VERSION', 'builtin') ~= 0
    mkdir vtk_1DCase;
    cd vtk_1DCase;
    mrsttovtk(G, states, 'states', '%f');
    return
end

% If MATLAB is used, then the plotToolbar is used to show the results. For
% this is necessary to add the mrst-gui module. 
mrstModule add mrst-gui
figure;
plotToolbar(G, states, 'field', 's:1', 'lockCaxis', true);
view([-10, 14]);
axis tight;
colorbar; caxis([0 1]);

% In this example the results are also print in vtk format if MATLAB is 
% used, which could be useful in different situations (e.g., to compare 
% simulation results of OPM (vtk format) and MRST using ParaView). 

mkdir vtk_1DCase;
cd vtk_1DCase;
mrsttovtk(G, states, 'states', '%f');

%% The mrsttovtk function
%
% The 'mrsttovtk' function might be compatible with other mrst examples 
% where the grid is given in a 3D format (e.g., it works for the 
% 'geothermalExampleHTates' in the geothermal module [after running that 
% geothermal example, uncomment and run the following 4 lines and open
% the created 'statestermal.pvd' in ParaView])).
% mrstModule add ad-micp
% mkdir vtk_3Dthermal;
% cd vtk_3Dthermal;
% mrsttovtk(G, states, 'statestermal', '%f');

%% Copyright notice
%{
Copyright 2021, NORCE Norwegian Research Centre AS, Computational
Geosciences and Modeling.

This file is part of the ad-micp module.

ad-micp is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

ad-micp is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this file.  If not, see <http://www.gnu.org/licenses/>.
%}
