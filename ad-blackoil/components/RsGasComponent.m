classdef RsGasComponent < ComponentImplementation
    properties
        phaseIndex % Index of phase this component belongs to
    end
    
    methods
        function [c, phasenames] = getComponentDensity(component, model, state, varargin)
            [c, phasenames] = getComponentDensity@ComponentImplementation(component, model, state, varargin{:});
            gix = strcmpi(ph, 'g');
            [b, rs] = model.getProps(state, 'ShrinkageFactors', 'rs');
            rhoS = model.getSurfaceDensities();
            oix = strcmpi(ph, 'o');
            rhoGS = rhoS(gix);
            bO = b{oix};
            bG = b{gix};
            c{oix} = rs.*rhoGS.*bO;
            c{gix} = rhoGS.*bG;
        end
    end
end