function [] = processRestartDiagnostics(casenm, varargin)
opt = struct('outputdir',         [], ...
             'multiple',        true, ...
             'maxTOF',     500*year);

[restartdir, prefx] = fileparts(casenm);

if isempty(opt.outputdir)
    opt.outputdir = fullfile(restartdir, 'mrst_diagnostics');
end

flag = mkdir(opt.outputdir);
if ~flag
    error('Unable to create directory...')
end

init = readEclipseOutputFileUnFmt([casenm, '.INIT']);
grid = readEclipseOutputFileUnFmt([casenm, '.EGRID']); 

%[fluid, pvtdeck] = initFluidFromOutput(init);

% only simulation-grid here
G = initGridFromEclipseOutput(init, grid, 'outputSimGrid', true);
[G, Gs] = deal(G{1}, G{2});

Gs.PORV = G.PORV;
info = processEclipseRestartSpec(casenm);

steps = 1:numel(info.time);
startday = datenum(info.date(1, [3 2 1]));
time.prev = startday + info.time( max(steps-1,1) ) - info.time(1);
time.cur  = startday + info.time( steps ) - info.time(1);

states = convertRestartToStates(casenm, Gs, 'restartInfo', info, 'splitWellsOnSignChange', true);
%states = addFormationVolumeFactors(states, fluid, pvtdeck.RUNSPEC);
%states = addConnectionPhaseFluxes(states, fluid, pvtdeck.RUNSPEC);

if opt.multiple
    t0 = tic;
    fprintf('Computing diagnostics:     ')
    fnm = @(k)fullfile(opt.outputdir, sprintf([prefx,'_diagn%0.4d.mat'], k));
    for k = 1:numel(states)
        fprintf('\b\b\b\b%3.1d%%', round(100*k/numel(states)));
        tmptime = struct('cur', time.cur(k), 'prev', time.prev(k));
        cur = struct('states', {states(k)}, 'diagnostics', [], 'time', tmptime);
        % switch off verbose here
        vb = mrstVerbose;
        mrstVerbose('off');
        cur = computeDiagnostics(Gs, cur, opt.maxTOF); %#ok
        mrstVerbose(vb);
        save(fnm(k), '-struct', 'cur');
        dt = toc(t0);
        time_left =  (numel(states)-k+1)*dt/k; %#ok
    end
    fprintf(', done\n')
else
    error('currently supports only mulitple')
end
end


function states = addConnectionPhaseFluxes(states, fluid, runspec)
% from output we typically only have total volume connection fluxes. 
% Approx water flux by using bW at bhp 
if runspec.DISGAS && runspec.VAPOIL
    warning('Both occuring DISGAS and VAPOIL, connection fluxes will not be accurate')
end
assert(runspec.OIL && runspec.WATER, 'Current code assumes both oil and water present')
for sk = 1:numel(states)
    ws = states{sk}.wellSol;
    for wk = 1:numel(ws)
        if size(ws(wk).flux, 2) == 1
            c = ws(wk).cells;
            resflux = ws(wk).flux;
            qwr = ws(wk).cqs(:,1)./states{sk}.b(c,1);
            qor = ws(wk).cqs(:,2)./states{sk}.b(c,2);
            if runspec.VAPOIL
                qor = qor - ws(wk).cqs(:,3).*states{sk}.rv(c)./states{sk}.b(c,2);
            end
            if ~runspec.GAS
                ws(wk).flux = [qwr, qor];
            else
                qgr = ws(wk).cqs(:,3)./states{sk}.b(c,3);
                if runspec.DISGAS
                    qgr = qgr - ws(wk).cqs(:,2).*states{sk}.rs(c)./states{sk}.b(c,3);
                end
                ws(wk).flux = [qwr, qor, qgr];
            end
            % if remove crossflow ...
            %ws(wk).flux(resflux==0,:) = 0;
        end
    end
    states{sk}.wellSol = ws;
end
end
    

