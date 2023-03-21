function [info, present] = dataset_johansen()
% Info function for Johansen dataset. Use getDatasetInfo or getAvailableDatasets for practical purposes.

%{
Copyright 2009-2023 SINTEF Digital, Mathematics & Cybernetics.

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
        'name', 'Johansen', ...
        'website', 'https://www.sintef.no/Projectweb/MatMorA/Downloads/Johansen/', ...
        'fileurl', 'https://www.sintef.no/contentassets/124f261f170947a6bc51dd76aea66129/johansen.zip', ...
        'hasGrid', true, ...
        'hasRock', true, ...
        'description', 'The Johansen formation is a candidate site for large-scale CO2 storage offshore the south-west coast of Norway. The data set contains four different models: one model of the whole field and three sector models with different vertical resolution. The data sets are published courtesy of the MatMoRA project funded by the Climit program at the Research Council of Norway.', ...
        'hasFluid', false, ...
        'examples', {'showJohansen', ...
                     'book:showJohansenNPD', ...
                     'book:coarsenJohansen', ...
                     'co2lab:makeJohansenVEgrid', ...
                     'co2lab:runJohansenVE', ...
                     }, ...
        'filesize',    39.2, ...
        'modelType', 'Corner-point' ...
         );
end
