function h = mapPlot(h, Gt, varargin)
% Plot a map of the 2D formation, with optional features.
% NB: Make sure to open a figure and set 'hold on' before calling this function.
%
% SYNOPSIS:
%   function mapPlot(Gt, varargin)
%
% DESCRIPTION:
%
% PARAMETERS:
%   Gt       - 
%   varargin - 
%
% RETURNS:
%   mapPlot(Gt, - 
%
    opt.traps = [];
    opt.trapsets = []; % if we want multiple colors on traps, this should be
                       % a cell array with trap indices for each color
                       % group.  (Default is a single set).
    opt.trapcolor = [1 0 0]; % if we want multiple colors on traps, there
                             % should be one line per trapset. 
    opt.trapalpha = 0.3;
    opt.rivers = []; % 'cell_lines' in trap structure
    opt.rivercolor = [1 0 0];
    opt.plumes = [];
    opt.labels = [];
    opt.title = [];
    opt.wellcells = [];
    opt.well_numbering = false;
    opt.plume_h_threshold = 0.3;
    opt.casecolors = 'rbcgm';
    opt.maplines = 40;
    opt.quickclip = true;
    opt.background = [];
    opt.backgroundalpha = 1;
    opt.colorbar = 'background';
    opt.colorbarposition = 'South';
    
    opt = merge_options(opt, varargin{:});
    figure(h); hold on;
    ax = get(h, 'currentaxes');
    
    % Setting title
    if(~isempty(opt.title))
        title(opt.title, 'FontSize', 16);
    end
    % plotting map
    drawContours(ax, Gt, Gt.cells.z, opt.maplines, 'color', 'k');
    
    % drawing background
    if ~isempty(opt.background)
       % eliminating any negative infinite values
       neginf = opt.background == -Inf;
       opt.background(neginf) = min(opt.background(~neginf));
       ax = drawSmoothField(ax, Gt, ...
                            opt.background , 200           , ...
                            'quickclip'    , opt.quickclip , ...
                            'alpha'        , opt.backgroundalpha);
       if strcmpi(opt.colorbar, 'background')
           caxis([min(opt.background), max(opt.background)]);
           hh = colorbar('peer', ax, opt.colorbarposition);
           set(hh, 'fontSize', 20);
       end
    end    
    
    % Plotting plumes, if any
    num_plumes = size(opt.plumes, 2);
    if num_plumes > numel(opt.casecolors)
        error('Not enough colors to draw %i plumes', num_plumes);
    end

    for c_ix = 1:num_plumes
        drawContours(ax, ...
                     Gt, opt.plumes(:, c_ix), opt.plume_h_threshold, ...
                     'color', opt.casecolors(c_ix), 'lineWidth', 2, ...
                     'quickclip', opt.quickclip);
    end
    
    % Plotting plume labels
    if num_plumes > 1
        legend(opt.labels, 'Location', 'SouthEast');    
    end
    
    % plotting wellcells
    plot(Gt.cells.centroids(opt.wellcells,1), ...
         Gt.cells.centroids(opt.wellcells,2), ...
         'ok', 'MarkerSize',10, 'MarkerFaceColor', 'k','MarkerEdgeColor', ...
         'y');
    if opt.well_numbering
        xpos = Gt.cells.centroids(opt.wellcells,1);
        ypos = Gt.cells.centroids(opt.wellcells,2);
        labels = [repmat(' ', numel(xpos), 1), num2str([1:numel(xpos)]')]; %#ok
        text(xpos, ypos, labels, 'fontsize', 24);
    end
    
    % Plotting traps
    if ~isempty(opt.traps)
        % colorize traps
        if isempty(opt.trapsets) || size(opt.trapcolor, 1) == 1
            % all traps will have same color
            colorizeRegion(h, Gt, opt.traps, opt.trapcolor(1,:), 'faceAlpha' , opt.trapalpha);
        else
            % check that we have enough colors
            assert(size(opt.trapcolor,1) >= numel(opt.trapsets)); 
            color_ix = 1;
            for ts = opt.trapsets
                traps = ismember(opt.traps, [ts{:}]);
                colorizeRegion(h, Gt, traps, opt.trapcolor(color_ix,:), ...
                               'faceAlpha', opt.trapalpha);
                color_ix = color_ix + 1;
            end
        end
    end
    if ~isempty(opt.rivers)
        % sketch rivers
        for tr = opt.rivers
            for r = tr{:}
                draw_cell_connections(Gt, r{:}, 'color', opt.rivercolor, 'lineWidth', 1);
            end
        end
    end
    

    
end

% ============================================================================

% ----------------------------------------------------------------------------
function draw_cell_connections(Gt, cells, varargin)

    x = Gt.cells.centroids(cells, 1);
    y = Gt.cells.centroids(cells, 2);
    smooth=@(x) x;
    x = smooth(x);
    y = smooth(y);
    plot(x, y, varargin{:});
    
end

