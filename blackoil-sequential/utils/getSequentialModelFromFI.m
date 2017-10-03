function model = getSequentialModelFromFI(fimodel, varargin)
% For a given fully implicit model, output the corresponding pressure/transport model 
    if isa(fimodel, 'SequentialPressureTransportModel')
        % User gave us a sequential model! We do not know why, but in that
        % case we just return it straight back.
        model = fimodel;
        return
    end
    rock  = fimodel.rock;
    fluid = fimodel.fluid;
    G     = fimodel.G;
    
    switch lower(class(fimodel))
        case 'twophaseoilwatermodel'
            pressureModel  = PressureOilWaterModel(G, rock, fluid, ...
                                                    'oil',   fimodel.oil, ...
                                                    'water', fimodel.water);
            transportModel = TransportOilWaterModel(G, rock, fluid, ...
                                                    'oil',   fimodel.oil, ...
                                                    'water', fimodel.water);
        case 'threephaseblackoilmodel'
            pressureModel  = PressureBlackOilModel(G, rock, fluid, ...
                                                    'oil',    fimodel.oil, ...
                                                    'water',  fimodel.water, ...
                                                    'gas',    fimodel.gas, ...
                                                    'disgas', fimodel.disgas, ...
                                                    'vapoil', fimodel.vapoil ...
                                                );
            transportModel = TransportBlackOilModel(G, rock, fluid, ...
                                                    'oil',    fimodel.oil, ...
                                                    'water',  fimodel.water, ...
                                                    'gas',    fimodel.gas, ...
                                                    'disgas', fimodel.disgas, ...
                                                    'vapoil', fimodel.vapoil ...
                                                    );
        case 'threephasecompositionalmodel'
            eos = fimodel.EOSModel;
            pressureModel = PressureCompositionalModel(G, rock, fimodel.fluid, eos.fluid, ...
                'water', fimodel.water);
            transportModel = TransportCompositionalModel(G, rock, fimodel.fluid, eos.fluid, ...
                'water', fimodel.water);

            pressureModel.EOSModel = eos;
            transportModel.EOSModel = eos;
            
        case 'oilwaterpolymermodel'
            pressureModel  = PressureOilWaterPolymerModel(G, rock, fluid, ...
                                                    'oil',     fimodel.oil, ...
                                                    'water',   fimodel.water, ...
                                                    'polymer', fimodel.polymer);
            transportModel = TransportOilWaterPolymerModel(G, rock, fluid, ...
                                                    'oil',     fimodel.oil, ...
                                                    'water',   fimodel.water, ...
                                                    'polymer', fimodel.polymer);
            pressureModel.operators = fimodel.operators;
            transportModel.operators = fimodel.operators;
            model = SequentialPressureTransportModelPolymer(...
                pressureModel, transportModel, varargin{:});
        otherwise
            error('mrst:getSequentialModelFromFI', ...
            ['Sequential model not implemented for ''' class(fimodel), '''']);
    end
    pressureModel.operators = fimodel.operators;
    transportModel.operators = fimodel.operators;
    
    model = SequentialPressureTransportModel(pressureModel, transportModel, varargin{:});
end

%{
Copyright 2009-2017 SINTEF ICT, Applied Mathematics.

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

