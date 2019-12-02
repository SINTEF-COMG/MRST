function [info, present] = dataset_co2atlas()
% Info function for CO2lab dataset. Use getDatasetInfo or getAvailableDatasets for practical purposes.

%{
Copyright 2009-2019 SINTEF Digital, Mathematics & Cybernetics.

This file is part of The MATLAB Reservoir Simulation Toolbox (MRST).

MRST is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

MRST is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with MRST.  If not, see <http://www.gnu.org/licenses/>.
%}
    [info, present] = datasetInfoStruct(...
        'name', 'CO2Atlas', ...
        'website', 'http://www.npd.no/en/Publications/Reports/CO2-Storage-Atlas-/', ...
        'fileurl', 'https://www.sintef.no/contentassets/124f261f170947a6bc51dd76aea66129/co2atlas.zip', ...
        'hasGrid', true, ...
        'hasRock', false, ...
        'description', ['The Norwegian Petroleum Directorate has produced ' ...
                        'data on possible CO2 storage sites on the Norwegian ' ...
                        'Continental Shelf.  Formations in the North Sea, the ' ...
                        'Norwegian Sea and the Barents Sea are available as ' ...
                        'separate datasets.  The present dataset covers ' ...
                        'formations in the North Sea.  It includes thickness ' ...
                        'and top surface maps of a wide variety of aquifers ' ...
                        'and rock formations.  The routine getAtlasGrid under ' ...
                        'the co2lab module can produce simulation grids from ' ...
                        'the dataset.'], ...
        'hasFluid', false, ...
        'filesize',    15.6, ...
        'examples', { 'co2lab:showCO2atlas', ...
                      'co2lab:describeAtlas', ...
                      'co2lab:exploreCapacity', ...
                      'co2lab:exploreSimulation', ...
                      'co2lab:modelsFromAtlas', ...
                      'co2lab:showFormationOutlines', ...
                      'co2lab:firstPlioExample', ...
                      'co2lab:firstPlioExampleFI', ...
                      'co2lab:secondPlioExample' ...
                      'co2lab:coarseningEffects', ...
                      'co2lab:subscaleResolution', ...
                      'co2lab:runUtsira', ...
                      'co2lab:trapsHuginWest',...
                      'co2lab:trapsJohansen', ...
                      'co2lab:resJohansen', ...
                      'co2lab:resTiltUtsira', ...
                      }, ...                 
        'modelType', 'Depth and thickness maps' ...
         );
end
