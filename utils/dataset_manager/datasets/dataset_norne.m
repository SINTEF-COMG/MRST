function [info, present] = dataset_norne()
% Info function for Norne dataset. Use getDatasetInfo or getAvailableDatasets for practical purposes.

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
        'name', 'Norne', ...
        'website', 'http://www.ipt.ntnu.no/~norne/wiki/doku.php?id=english:nornebenchmarkcase2', ...
        'fileurl', '', ...
        'downloadFcn', @() makeNorneSubsetAvailable() && makeNorneGRDECL(), ...
        'hasGrid', true, ...
        'hasRock', true, ...
        'hasFluid', true, ...
        'filesize', 20.0, ...
        'cells', 44420, ...
        'examples', {'showNorne', ...
	             'book:runNorneSynthetic', ...
                     'incomp:incompExampleNorne1ph', ...
                     'incomp:incompExampleNorne2ph', ...
                     'coarsegrid:coarseGridExampleNorne', ...
                     }, ...
        'description', [ 'Simulation model of the Norne field in the ', ...
            'Norwegian Sea operated by Statoil. First made available ', ...
            'to researchers via NTNU. Later, published as an open ', ...
            'data set by the Open Porous Media (OPM) initiative. ', ...
            'Run scripts makeNorneSubsetAvailable() and ', ...
            'makeNorneGRDECL() to set up the Eclipse input files'], ...
        'modelType', 'Three-phase, black-oil, corner-point' ...
         );
end
