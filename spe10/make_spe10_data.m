function ok = make_spe10_data
%Create on-disk (MAT file) representation of SPE 10 'rock' data.
%
% SYNOPSIS:
%   ok = make_spe10_data
%
% PARAMETERS:
%   None.
%
% RETURNS:
%   ok - Status flag indicating successful creation of on-disk 'rock' data.
%
% NOTE:
%   The on-disk representation is a 'rock' structure stored in the file
%   'spe10_rock.mat' in the directory identified by
%
%       getDatasetPath('spe10')
%
%   The permeability data is stored in SI units (metres squared).
%
% SEE ALSO:
%   `getDatasetPath`, `getSPE10rock`, `makeSPE10DataAvailable`.

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

   ok = makeSPE10DataAvailable();
end
