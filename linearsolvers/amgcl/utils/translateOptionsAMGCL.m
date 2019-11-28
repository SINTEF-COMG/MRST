function [n, name, description] = translateOptionsAMGCL(name, value)
%Translate AMGCL String Option Value to Integer Code
%
% SYNOPSIS:
%    n = translateOptionsAMGCL(name, value)
%
% PARAMETERS:
%   name  - Option name.  Character vector.  Must be one of 'precondtioner',
%           'coarsening', 'relaxation', or 'solver'.
%
%   value - Option value.  String (character vector) pertaining to 'name'.
%
% RETURNS:
%   n - Integer option value known to underlying MEX gateway.
%
% SEE ALSO:
%   `callAMGCL`, `amgcl_matlab`, `getAMGCLMexStruct`.

%{
Copyright 2009-2018 SINTEF Digital, Mathematics & Cybernetics.

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
    assert(ischar(name), 'First input must be a name');

    switch lower(name)
        case 'preconditioner'
            choices = {'amg', 'relaxation', 'dummy'};
            descriptions = {'Algebraic multigrid', ...
                            'Relaxation as preconditioner', ...
                            'Dummy (do nothing)'};

        case 'coarsening'
            choices = {'smoothed_aggregation', 'ruge_stuben', ...
                       'aggregation', 'smoothed_aggr_emin'};
            descriptions = {'Smoothed aggregation. Parameters: aggr_eps_strong, aggr_over_interp, aggr_relax.', ...
                            'Ruge-Stuben / classic AMG coarsening. Parameters: rs_eps_strong, rs_trunc, rs_eps_trunc', ...
                            'Aggregation with constant interpolation. Parameters: aggr_eps_strong, aggr_over_interp, aggr_relax.', ...
                            'Smoothed aggregation (energy minimizing). Parameters: aggr_eps_strong, aggr_over_interp, aggr_relax.'};

        case 'relaxation'
            choices = {'spai0', 'gauss_seidel', 'ilu0', 'iluk',...
                       'ilut', 'damped_jacobi', 'spai1', 'chebyshev'};
            descriptions = {'Sparse approximate inverse (order 0).', ...
                            'Gauss-Seidel smoothing.', ...
                            'Incomplete LU-factorization with zero fill-in - ILU(0). Parameters: ilu_damping.', ...
                            'Incomplete LU-factorization of order k - ILU(k). Parameters: ilu_damping, ilu_k parameter.', ...
                            'Incomplete LU-factorization with thresholding - ILU(t). Parameters: ilu_damping, ilut_tau.', ...
                            'Damped Jacobi smoothing. Parameters: jacobi_damping.', ...
                            'Sparse approximate inverse (order 1).', ...
                            'Chebyshev smoothing. Parameters: chebyshev_degree, chebyshev_lower, chebyshev_power_its.'};

        case 'solver'
            choices = {'bicgstab', 'cg', 'bicgstabl', 'gmres', 'lgmres', 'fgmres', 'idrs'};
            descriptions = {'Biconjugate gradient stabilized method.', ...
                            'Conjugate gradient method.', ...
                            'Biconjugate gradient stabilized method (l variant). Parameters: bicgstab_convec, bicgstab_delta, bicgstab_l.', ...
                            'Generalized minimal residual method. Parameters: gmres_m.', ...
                            'Generalized minimal residual method (l variant). Parameters: lgmres_always_reset, lgmres_k, lgmres_store_av.', ...
                            'Generalized minimal residual methid (f variant). Parameters: -', ...
                            'Induced Dimension Reduction method Parameters: idrs_omega, idrs_replacement, idrs_s.' ...
                            };

        otherwise
            error('Option:Unknown', 'Unknown option: ''%s''', name);
    end
    [n, name, description] = translate_option(name, choices, descriptions, value);
end


function [index, name, description] = translate_option(category, names, descriptions, value)
   index = mapArgument(value, names, category);
   if ischar(index)
       name = names;
       description = descriptions;
   else
       name = names{index};
       description = descriptions{index};
   end
end

function index = mapArgument(value, types, groupName)
   if isempty(value)
       % Get everything
       index = ':';
   elseif ischar(value)
       % String corresponding to valid option
       index = find(strcmpi(types, value));
       if isempty(index)
           error(['Unknown:', groupName], 'Unknown %s name: ''%s''', ...
                                            groupName, value);
       end
   else
       % Numeric index
       index = value;
       assert(isnumeric(value));
       assert(isnumeric(value) <= numel(types));
   end
end
