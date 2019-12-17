function u = unitConversionFactors(inputUnit, outputUnit)
% Get unit conversion factors from/between given unit(s)
%
% SYNOPSIS:
%   u = unitConversionFactors(inputUnit)
%   u = unitConversionFactors(inputUnit, outputUnit)
%
% PARAMETERS:
%   inputUnit - String, unit name must be either 'METRIC', 'FIELD', 'LAB', 
%               'PVT_M', or 'SI'
%   
%  outputUnit - Unit name as above. Default value: SI
%
% RETURNS:
%   u - Data structure of unit conversion factors from inputUnit
%       to outputUnit, such that e.g. for pressure,
%               p [outputUnit] = (p [inputUnit] )*u.press
%          
% SEE ALSO:
%   `convertDeckUnits`,

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
if nargin < 2
    outputUnit = 'si';
end
inputUnit  = lower(inputUnit);
outputUnit = lower(outputUnit);

u = unit_system(inputUnit);
% handle case of non-SI output
if ~strcmpi('si', outputUnit)
    u_out = unit_system(outputUnit);
    u     = generalConversionFactors(u, u_out);
end
u.unit_in  = inputUnit;
u.unit_out = outputUnit;

end

%--------------------------------------------------------------------------

function u = generalConversionFactors(u_in, u_out)
u = u_out;
flds = setdiff(fieldnames(u_in), {'tempoffset'});
for k = 1:numel(flds)
    fld = flds{k};
    u.(fld) = u_in.(fld)/u_out.(fld);
end
% treat temperature offset
u.tempoffset = u_in.tempoffset - u_out.tempoffset/u.temp; 
end

%--------------------------------------------------------------------------

function u = unit_system(nm)
switch nm
    case 'metric'
        u = struct('length'      , meter               , ...
            'area'        , meter^2             , ...
            'invarea'     , meter^(-2)          , ...
            'time'        , day                 , ...
            'density'     , kilogram / meter^3  , ...
            'press'       , barsa               , ...
            'temp'        , Kelvin              , ... % Abs. temp
            'tempoffset'  , 273.15              , ... % Rel. Temp
            'mol'         , kilo                , ...
            'mass'        , kilogram            , ...
            'concentr'    , kilogram / meter^3  , ... % Concentration
            'compr'       , 1 / barsa           , ... % Compressibility
            'viscosity'   , centi*poise         , ...
            'surf_tension', Newton / meter      , ...
            'perm'        , milli*darcy         , ...
            'liqvol_s'    , meter^3             , ... % Liquid vol , surf
            'liqvol_r'    , meter^3             , ... % Liquid vol , res
            'gasvol_s'    , meter^3             , ... % Gas vol    , surf
            'gasvol_r'    , meter^3             , ... % Gas vol    , res
            'volume'      , meter^3             , ... % Geometric vol
            'trans'       , centi*poise * meter^3 / (day * barsa), ...
            'rockcond'    , kilo*joule / (meter*day*Kelvin),       ...
            'volumheatcapacity', kilo*joule / (meter^3*Kelvin),    ...
            'massheatcapacity' , kilo*joule / (kilogram*Kelvin));
        
    case 'field'
        u = struct('length'      , ft          , ...
            'area'        , ft^2        , ...
            'invarea'     , ft^(-2)     , ...
            'time'        , day         , ...
            'density'     , pound / ft^3, ...
            'press'       , psia        , ...
            'temp'        , Rankine     , ...
            'tempoffset'  , 459.67      , ... % Rel. Temp
            'mol'         , pound*kilo  , ...
            'mass'        , pound       , ...
            'concentr'    , pound / stb , ... % Concentration
            'compr'       , 1 / psia    , ...
            'viscosity'   , centi*poise , ...
            'surf_tension', lbf / inch  , ...
            'perm'        , milli*darcy , ...
            'liqvol_s'    , stb         , ...
            'liqvol_r'    , stb         , ...
            'gasvol_s'    , 1000 * ft^3 , ... % Mscf
            'gasvol_r'    , stb         , ...
            'volume'      , ft^3        , ... % Geometric vol
            'trans'       , centi*poise * stb / (day * psia), ...
            'rockcond'    , btu / (ft*day*Rankine),           ...
            'volumheatcapacity', btu / (ft^3*Rankine),        ...
            'massheatcapacity' , btu / (pound*Rankine));
        
    case 'lab'
        u = struct('length'      , centi*meter           , ...
            'area'        , (centi*meter)^2       , ...
            'invarea'     , (centi*meter)^(-2)    , ...
            'time'        , hour                  , ...
            'density'     , gram / (centi*meter)^3, ...
            'press'       , atm                   , ...
            'temp'        , Kelvin                , ...
            'tempoffset'  , 273.15              , ... % Rel. Temp
            'mol'         , 1                     , ...
            'mass'        , gram*kilo             , ...
            'concentr'    , gram / (centi*meter)^3, ...
            'compr'       , 1 / atm               , ...
            'viscosity'   , centi*poise           , ...
            'surf_tension', dyne / (centi*meter)  , ...
            'perm'        , milli*darcy           , ...
            'liqvol_s'    , (centi*meter)^3       , ...
            'liqvol_r'    , (centi*meter)^3       , ...
            'gasvol_s'    , (centi*meter)^3       , ...
            'gasvol_r'    , (centi*meter)^3       , ...
            'volume'      , (centi*meter)^3       , ... % Geometric vol
            'trans'       , centi*poise * (centi*meter)^3 / (hour * atm), ...
            'rockcond'    , joule / (centi*meter*hour*Kelvin),            ...
            'volumheatcapacity', joule / ((centi*meter)^3*Kelvin),        ...
            'massheatcapacity' , joule / (gram*Kelvin));
        
    case 'pvt_m'
        u = struct('length'      , meter               , ...
            'area'        , meter^2             , ...
            'invarea'     , meter^(-2)          , ...
            'time'        , day                 , ...
            'density'     , kilogram / meter^3  , ...
            'press'       , atm                 , ...
            'temp'        , Kelvin              , ... % Abs. temp
            'tempoffset'  , 273.15              , ... % Rel. Temp
            'mol'         , kilo                , ...
            'mass'        , kilogram            , ...
            'concentr'    , kilogram / meter^3  , ... % Concentration
            'compr'       , 1 / atm             , ... % Compressibility
            'viscosity'   , centi*poise         , ...
            'surf_tension', Newton / meter      , ...
            'perm'        , milli*darcy         , ...
            'liqvol_s'    , meter^3             , ...
            'liqvol_r'    , meter^3             , ...
            'gasvol_s'    , meter^3             , ...
            'gasvol_r'    , meter^3             , ...
            'volume'      , meter^3             , ... % Geometric vol
            'trans'       , centi*poise * meter^3 / (day * atm), ...
            'rockcond'    , kilo*joule / (meter*day*Kelvin),     ...
            'volumheatcapacity', kilo*joule / (meter^3*Kelvin),  ...
            'massheatcapacity' , kilo*joule / (kilogram*Kelvin));
        
    case 'si'
        % SI units.  MRST extension.  Idempotency.
        u = struct('length'      , 1, ...
            'area'        , 1, ...
            'invarea'     , 1, ...
            'time'        , 1, ...
            'density'     , 1, ...
            'press'       , 1, ...
            'temp'        , 1, ...
            'tempoffset'  , 0, ... % Always Kelvin
            'mol'         , 1, ...
            'mass'        , 1, ...
            'concentr'    , 1, ...
            'compr'       , 1, ...
            'viscosity'   , 1, ...
            'surf_tension', 1, ...
            'perm'        , 1, ...
            'liqvol_s'    , 1, ...
            'liqvol_r'    , 1, ...
            'gasvol_s'    , 1, ...
            'gasvol_r'    , 1, ...
            'volume'      , 1, ...
            'trans'       , 1, ...
            'rockcond'    , 1, ...
            'volumheatcapacity', 1, ...
            'massheatcapacity' , 1);
    otherwise
        error('Input unit system ''%s'' unknown, must be either METRIC, FIELD, LAB, PVT_M, or SI.', upper(nm));
end

end