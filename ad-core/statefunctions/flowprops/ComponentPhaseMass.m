classdef ComponentPhaseMass < StateFunction & ComponentProperty
    % Mass of each component, in each phase.
    properties
        includeStandard = true;
    end
    
    methods
        function gp = ComponentPhaseMass(model, varargin)
            gp@StateFunction(model, varargin{:});
            gp@ComponentProperty(model, 'getComponentMass');
            gp.label = 'M_{i,\alpha}';
            if gp.includeStandard
                gp = gp.dependsOn({'Density', 'PoreVolume'}, 'PVTPropertyFunctions');
            end
        end
        function v = evaluateOnDomain(prop, model, state)
            ncomp = model.getNumberOfComponents();
            nph = model.getNumberOfPhases();
            if prop.includeStandard
                [rho, pv] = prop.getEvaluatedExternals(model, state, 'Density', 'PoreVolume');
                s = model.getProp(state, 's');
                extra = {s, pv, rho};
            else
                extra = {};
            end
            v = cell(ncomp, nph);
            for c = 1:ncomp
                v(c, :) = model.Components{c}.getComponentMass(model, state, extra{:});
            end
        end
    end
end

%{
Copyright 2009-2020 SINTEF Digital, Mathematics & Cybernetics.

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
