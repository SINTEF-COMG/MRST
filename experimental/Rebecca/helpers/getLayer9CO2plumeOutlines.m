function [ plume ] = getLayer9CO2plumeOutlines( )

% the following .mat files which are loaded must be placed on the current
% working directory path. These files can be downloaded from 
% https://bitbucket.org/mrst/mrst-co2lab/downloads

% note that the years 2006a and 2006b correspond to the same plume data for
% the given year, however any connecting lines between separate plume
% regions have been removed. TODO: use these better polygon files instead
% of the 2006 polygon file.

load layer9_polygons_1999.mat;
plume{1}.outline = CO2plumeOutline; clear CO2plumeOutline
plume{1}.year    = 1999;

load layer9_polygons_2001.mat;
plume{2}.outline = CO2plumeOutline; clear CO2plumeOutline
plume{2}.year    = 2001;

load layer9_polygons_2002.mat;
plume{3}.outline = CO2plumeOutline; clear CO2plumeOutline
plume{3}.year    = 2002;

load layer9_polygons_2004.mat;
plume{4}.outline = CO2plumeOutline; clear CO2plumeOutline
plume{4}.year    = 2004;

load layer9_polygons_2006.mat;
plume{5}.outline = CO2plumeOutline; clear CO2plumeOutline
plume{5}.year    = 2006;

%load layer9_polygons_2006a.mat;
%plume{6}.outline = CO2plumeOutline; clear CO2plumeOutline
%plume{6}.year    = 2006.3;

%load layer9_polygons_2006b.mat;
%plume{7}.outline = CO2plumeOutline; clear CO2plumeOutline
%plume{7}.year    = 2006.6;

load layer9_polygons_2008.mat;
plume{6}.outline = CO2plumeOutline; clear CO2plumeOutline
plume{6}.year    = 2008;


end

