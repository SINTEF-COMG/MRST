function [updata, report] = upPcOW(block, updata, varargin)
% Upscale capillary pressure curves.
%
% It is assumed that all capillary pressure curves are monotone.
% 
% The upscaling is done my looping over different values of the capillery
% pressure. For each value, this value is set in all cells, and then the
% capillary pressure function is inverted to find the saturation
% distribution. The saturation is then upscaled, and we have a pair of
% saturation/pcOW.
% 
opt = struct(...
    'nPointsInit', 20, ...   % Number of initial points
    'nPointsMax',  50, ...   % Maximum number of points
    'relTolSw',    0.01, ... % Relative to saturation scale
    'relTolPc',    0.01, ...  % Relative to pc scale
    'gravity',     false ...
    );
opt = merge_options(opt, varargin{:});

wantReport = nargout > 1;
timeStart = tic;
useGravity = opt.gravity;

G     = block.G;
fluid = block.fluid;

if ~isfield(fluid, 'pcOW')
	updata.pcOW = [];
    return
end

assert(isfield(fluid, 'pcOWInv'), ...
   'The fluid structure must have the field ''pcOWInv''. ');

pv    = block.pv;
pvTot = sum(pv);
nPointsInit = opt.nPointsInit;
nPointsMax  = opt.nPointsMax;
relTolSw    = opt.relTolSw;
relTolPc    = opt.relTolPc;

if useGravity
    % Gravity force value for each cell in the grid
    if isfield(fluid, 'rhoO')
        rhoO = fluid.rhoO;
    else
        rhoO = fluid.rhoOS;
    end
    if isfield(fluid, 'rhoW')
        rhoW = fluid.rhoW;
    else
        rhoW = fluid.rhoWS;
    end
    dRho = rhoW - rhoO;
    g    = 9.8066; % HARDCODED
    
    % Compute an estimate of the centroid of the grid block. This will be
    % the correct centroid is the grid is Cartesian, but otherwise, it may
    % be off.
    zCent = mean([max(G.cells.centroids(:,3)), ...
                  min(G.cells.centroids(:,3))]);

    % Set height relative to the zCent. Thus the returned xvec is the
    % capillary pressure at the height zCent.
    zi   = G.cells.centroids(:,3) - zCent;
    
    grav = dRho.*g.*zi;
else
    grav = 0;
end

% Find minimum and maximum pc in block
pc0   = fluid.pcOW( zeros(G.cells.num,1) ) + grav;
pc1   = fluid.pcOW( ones(G.cells.num,1) ) + grav;
pcMin = min(min(pc0), min(pc1));
pcMax = max(max(pc0), max(pc1));

% Allocate vectors
pcOWup = nan(nPointsMax, 2); % Each row is a pair of [sWup, pcOWup]

% Compute the initial set of equally spaces pc points
pcOWup(1:nPointsInit, 2) = linspace(pcMin, pcMax, nPointsInit)';
for i = 1:nPointsInit
   pc = pcOWup(i,2)*ones(G.cells.num, 1); % Set same pc in all cells
   sw = fluid.pcOWInv(pc - grav); % Invert capillary pressure curves
   pcOWup(i,1) = sum(sw.*pv) / pvTot; % Compute corresp. upscaled sat
end
sWMin = min(pcOWup(1:nPointsInit, 1));
sWMax = max(pcOWup(1:nPointsInit, 1));

% Continue to add points to the upscaled curve where the distance between
% two points is largest. We check distance in both directions.
nPointsExtra = nPointsMax - nPointsInit;
for i = 1:nPointsExtra+1 % Note: last iteration is just a check
   
   % Find maximum distance between two points in each direction
   [maxDiffSw, maxInxSw] = max(abs(diff(pcOWup(:,1))));
   [maxDiffPc, maxInxPc] = max(abs(diff(pcOWup(:,2))));
   
   % Scale the differences with the span
   maxDiffSw = maxDiffSw/(sWMax - sWMin);
   maxDiffPc = maxDiffPc/(pcMax - pcMin);
   
   if maxDiffSw < relTolSw && maxDiffPc < relTolPc
       % Both tolerences are met, and so we are done.
       if i < nPointsExtra+1
           % Remove nans at end of vectors and break out of loop
           last   = nPointsMax - (nPointsExtra-i+1);
           pcOWup = pcOWup(1:last,:);
       end
       break; % Break out of loop
   elseif i == nPointsExtra+1
       % Max number of iterations completed, but tolerences not met
       if mrstVerbose
           warning(['Upscaling pcOW: Tolerence not met. '...
               'sWdiff=%1.2e, pcdiff=%1.2e.'], maxDiffSw, maxDiffPc);
       end
       break; % Break out of loop
   end
   
   % Compute new pair of upscaled sw and pcow. Insert where the difference
   % in either direction is largest.
   if maxDiffSw > maxDiffPc
      inx = maxInxSw;
   else
      inx = maxInxPc;
   end
   pcup = mean(pcOWup([inx, inx+1],2));
   pc   = pcup*ones(G.cells.num,1); % Set same pc in all cells
   sw   = fluid.pcOWInv(pc - grav); % Invert capillary pressure curves
   swup = sum(sw.*pv) / pvTot; % Compute corresp. upscaled sat
   
   % Insert new values at correct place to keep sorted order
   pcOWup(inx+1:end,:) = [swup pcup; pcOWup(inx+1:end-1,:)];
   
end

% Flip if saturations decrease
if pcOWup(1,1) > pcOWup(2,1)
    pcOWup = flipud(pcOWup);
end

% Check that upscaled values are valid
assert( (all(diff(pcOWup(:,2)) > 0) || all(diff(pcOWup(:,2)) < 0) ), ...
        'Upscaled capillary pressure curve is not strictly monotonic');
assert( all(diff(pcOWup(:,1)) > 0), ...
        'Upscaled water saturation is not strictly increasing');

% Add upscaled data to structure
updata.pcOW = pcOWup;

totalTime = toc(timeStart);
if wantReport
    report.swreldiff = maxDiffSw;
    report.pcreldiff = maxDiffPc;
    report.gravity   = useGravity;
    report.time      = totalTime;
end

end



