function [ hfig, hax ] = subplotCO2simVsCO2obsData(Years2plot, inj_year, plume, sim_report, Gt, states, fluid, model, wellXcoord, wellYcoord, wellCoord_x, wellCoord_y, trapstruct, ZoomIntoPlume, ZoomX1, ZoomX2, ZoomY1, ZoomY2, CO2plumeOutline_SatTol)

% Reservoir Time2plot is an array of all times in seconds you wish to
% visualize the CO2 plume (saturation). If any times coorespond to the
% observation plume data, that plume outline is plotted as well.

ReservoirTime2plot  = (Years2plot - inj_year(1)+1 ).*(365*24*60*60); % seconds

bf = boundaryFaces(Gt);
maxMassCO2 = zeros(1,numel(ReservoirTime2plot));

figure; set(gcf, 'Position', [1000 1000 1500 1100])
hold on

for i = 1:numel(ReservoirTime2plot)
    
    % get reservoir time index
    [rti,~] = find(sim_report.ReservoirTime==ReservoirTime2plot(i));

    % meaningful profiles
    %press       = states{rti}.pressure;
    %pressDiffFromHydrostatic = press - initState.pressure;
    densityCO2  = fluid.rhoG(states{rti}.pressure);  % fluid.rhoG is function handle to get CO2 density
    satCO2      = states{rti}.s(:,2);
    massCO2     = model.rock.poro.*model.G.cells.volumes.* model.G.cells.H.*satCO2.*densityCO2; % kg
    
    maxMassCO2(i)= max(massCO2);
    
    subplot(2,numel(ReservoirTime2plot)/2,i)
    hold on

    plotFaces(Gt, bf, 'EdgeColor','k', 'LineWidth',3);
    plotCellData(Gt, massCO2/1e9, satCO2>CO2plumeOutline_SatTol, 'EdgeColor','none') % only plot plume that has sat > tolerance specified 
    title({'Mass of CO2 at';['year ', num2str(Years2plot(i))]}, 'fontSize', 18); axis equal
    hcb = colorbar; hcb.Label.String = 'Mt'; set(hcb, 'fontSize', 18)

    
    % add CO2 plume outline (check matching year):
    if plume{i}.year == Years2plot(i)
        disp('Plotting Observed CO2 plume outline...')
        line(plume{i}.outline(:,1), plume{i}.outline(:,2), 'LineWidth',3, 'Color','r')
    end
    
    % add injection point:
    % actual location
    plot(wellXcoord,wellYcoord,'o', ...
        'MarkerEdgeColor','k',...
        'MarkerFaceColor','r',...
        'MarkerSize',10)
    % simulated location
    plot(wellCoord_x,wellCoord_y,'x', ...
        'LineWidth',3,  ...
        'MarkerEdgeColor','k',...
        'MarkerFaceColor','k',...
        'MarkerSize',10)
    
    axis tight
    
    % We visualize the spill paths between structural traps
    mapPlot(gcf, Gt, 'traps', trapstruct.traps, 'rivers', trapstruct.cell_lines, ...
        'maplines',20); % default maplines is 40

end

% make plotting adjustments to subplots
axesHandles = get(gcf,'children');

% set caxis to be between 0 and the max CO2 mass value plotted in any of
% the subplots
cmax = max(maxMassCO2./1e9);
for i=1:numel(axesHandles)
    if strcmpi(axesHandles(i).Type,'axes')
        axesHandles(i).CLim = [0 cmax];
        
        if ZoomIntoPlume
           axesHandles(i).XLim = [ZoomX1 ZoomX2];
           axesHandles(i).YLim = [ZoomY1 ZoomY2];
        end
    end
end

hfig = gcf;
hax  = gca;

end

