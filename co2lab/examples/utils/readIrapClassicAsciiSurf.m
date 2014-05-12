function [x, y, Z, angle] = readIrapClassicAsciiSurf(filename)
%Read an .irap classic ASCII surface
%
% SYNOPSIS:
%   [x, y, z, angle] = readIrapClassicAsciiSurf('flatUP1')
%
% PARAMETERS:
%   name   - The filename of the .irap surface dataset.
%
% RETURNS:
%   x      - X coordinates for the uniformly spaced grid.
%
%   y      - Y coordinates for the uniformly spaced grid.
%
%   Z      - A numel(y) x numel(x) matrix of height values for the grid.
%
%   angle  - Grid angle
%
% EXAMPLE:
%    fname = fullfile(mrstPath('co2lab'), 'data', 'igems', ...
%                      'surfaces', 'flatNP1', '1_flatNP1.irap');
%    [x, y, Z, angle] = readIrapClassicAsciiSurf(fname);
%    surf(x,y,Z);
%    % Reverse ZDir according to MRST convention
%    set(gca, 'ZDir', 'reverse')
%
% SEE ALSO:
%   readIGEMSIRAP

%{
#COPYRIGHT#
%}

% Open the file for reading
fid = fopen(filename,'r');          % 'rt' means read text

if (fid < 0)
    errormsg = horzcat('Could not open file ', filename, ' for reading.');
    error(errormsg);   % just abort if error
end

%%

IRAP_MISSING  = 9999900.0;


%% reading header
[d, size] = fscanf(fid, '%d%d%f%f',4);
if (size == 4)
    dummy1 = d(1);
    ny = d(2);
    dx = d(3);
    dy = d(4);
else
    error('Error reading line 1 in header.');
end
% ----------- line shift --------------
[d, size] = fscanf(fid, '%f%f%f%f',4);
if (size == 4)
    xmin = d(1);
    xmax = d(2);
    ymin = d(3);
    ymax = d(4);
else
    error('Error reading line 2 in header.');
end
% ----------- line shift --------------
[d, size] = fscanf(fid, '%f%f%f%f',4);
if (size == 4)
    nx = d(1);
    angle = d(2);
    dummy2 = d(3); % xmin repeated
    dummy3 = d(4); % ymin repeated
else
    error('Error reading line 3 in header.');
end

[a, size] = fscanf(fid, '%f',7);
if (size ~= 7)
    error('Error reading line 4 in header.');
end

% consistency check
lx = xmax - xmin;
ly = ymax - ymin;
if (lx/(nx-1) ~= dx)
    error('Inconsistent data in file. dx != lx/(nx-1).');
end
if (ly/(ny-1) ~= dy)
    error('Inconsistent data in file. dy != ly/(ny-1).');
end

% passed consistency
n = nx * ny;
x = linspace(xmin, xmax, nx);
y = linspace(ymin, ymax, ny);

[Z, size] = fscanf(fid, '%f');
if (size ~= n)
    errormsg = horzcat('Inconsistent surface data. ', 'Expected: ',num2str(n), '. Found: ', num2str(size));
    error(errormsg);
end

% replacing missing witn nan
Z(Z==IRAP_MISSING) = NaN;


Z = reshape(Z,nx,ny)';
fclose(fid);



    
 
return

