function rock = initEclipseRock(deck)
%Extract rock properties from input deck
%
% SYNOPSIS:
%   rock = initEclipseRock(deck)
%
% PARAMETERS:
%   deck   - Raw input data in Deck form as defined by function
%            'readEclipseDeck'.
%
% RETURNS:
%   rock - Rock data stucture containing the following fields:
%            - perm -- Permeability values.  Layout as dictated by function
%                      'permTensor'.
%            - poro -- Porosity values.  Corresponds to 'PORO' keyword.
%            - ntg  -- Net-to-gross values.  Corresponds to 'NTG' keyword.
%            - cr   -- Rock compressibility.  Corresponds to item two of
%                      'ROCK' keyword (in PROPS section).
%            - pref -- Reference pressure for rock compressibility.  Data
%                      from item one of 'ROCK' keyword.
%
% NOTE:
%   A given 'rock' field is only created if the corresponding keyword is
%   present in the input deck.
%
% EXAMPLE:
%   %Create a rock data structure for active cells only
%
%   rock = initEclipseRock(deck)
%   rock = compressRock(rock, G.cells.indexMap)
%
% SEE ALSO:
%   `readEclipseDeck`, `convertDeckUnits`, `permTensor`, `compressRock`

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


   % Check consistency.
   if ~consistent(deck)
      error(msgid('Tensor:Inconsistent'), ...
            'Input tensor is not structurally consistent.');
   else
      % Permeability tensor.
      rock.perm = getTensor(deck);
   end

   % Other properties.
   rockprop = {'PORO', 'NTG'};
   for i = 1 : numel(rockprop)
      prop = regexprep(rockprop{i}, '\W', '_');
      if isfield(deck.GRID, prop)
         rock.(lower(prop)) = reshape(deck.GRID.(prop), [], 1);
      end
   end

   if isfield(deck.PROPS, 'ROCK')
      [rock.cr, rock.pref] = rock_compressibility(deck.PROPS);
   end
   
   rock = getRegions(rock, deck);
   rock = getScaling(rock, deck);
end

%--------------------------------------------------------------------------
% Private helpers follow.
%--------------------------------------------------------------------------

function rock = getRegions(rock, deck)
   hasPVT = isfield(deck.REGIONS, 'PVTNUM') && max(deck.REGIONS.PVTNUM > 1);
   hasSAT = isfield(deck.REGIONS, 'SATNUM') && max(deck.REGIONS.SATNUM > 1);
   hasIMB = isfield(deck.REGIONS, 'IMBNUM') && max(deck.REGIONS.IMBNUM > 1);
   if hasPVT || hasSAT || hasIMB
       regions = struct();
       if hasPVT
           regions.pvt = deck.REGIONS.PVTNUM;
       end
       
       if hasSAT
           regions.saturation = deck.REGIONS.SATNUM;
       end
       
       if hasIMB
           regions.imbibition = deck.REGIONS.IMBNUM;
       end
       rock.regions = regions;
   end
end

function rock = getScaling(rock, deck)
   if isfield(deck.RUNSPEC, 'ENDSCALE')
       nc = size(rock.poro, 1);
       rock.krscale = initRelpermScaling(deck, nc);
   end
end


function b = consistent(deck)
   k = false([3, 3]);

   grdecl = deck.GRID;

   k(1,1) = isfield(grdecl, 'PERMX' ) || isfield(grdecl, 'PERMXX');
   k(1,2) = isfield(grdecl, 'PERMXY') || isfield(grdecl, 'PERMYX');
   k(1,3) = isfield(grdecl, 'PERMXZ') || isfield(grdecl, 'PERMZX');

   k(2,1) = isfield(grdecl, 'PERMYX') || isfield(grdecl, 'PERMXY');
   k(2,2) = isfield(grdecl, 'PERMY' ) || isfield(grdecl, 'PERMYY');
   k(2,3) = isfield(grdecl, 'PERMYZ') || isfield(grdecl, 'PERMZY');

   k(3,1) = isfield(grdecl, 'PERMZX') || isfield(grdecl, 'PERMXZ');
   k(3,2) = isfield(grdecl, 'PERMZY') || isfield(grdecl, 'PERMYZ');
   k(3,3) = isfield(grdecl, 'PERMZ' ) || isfield(grdecl, 'PERMZZ');

   b = any(k(:));
   b = b && (k(1,1) || ~any([k(1,2), k(2,1), k(1,3), k(3,1)]));
   b = b && (k(2,2) || ~any([k(2,1), k(1,2), k(2,3), k(3,2)]));
   b = b && (k(3,3) || ~any([k(3,1), k(1,3), k(3,2), k(2,3)]));
end

%--------------------------------------------------------------------------

function perm = getTensor(deck, varargin)
   [vals, comp] = tensorValues(deck.GRID);

   [i, j] = find(comp > 1);
   if all(i == j)
      % Diagonal.
      assert (numel(i) == 3);
   else
      % Full, symmetric.  Use upper triangular part.
      assert (numel(i) == 9);
      i = [1, 1, 1, 2, 2, 3] .';
      j = [1, 2, 3, 2, 3, 3] .';
   end

   comp = comp(sub2ind([3, 3], i, j));
   if numel(comp) == 3 && all(diff(comp) == 0)
      % Return only single-component tensor when isotropic.
      comp = comp(1);
   end

   perm = vals(:, comp);
end

%--------------------------------------------------------------------------

function [cr, pref] = rock_compressibility(props)
   cr = props.ROCK(:, 2);
   pref = props.ROCK(:, 1);

   cr(isnan(cr)) = 0.0;  % E100 default.
end

%--------------------------------------------------------------------------

function [vals, comp] = tensorValues(grdecl)
   nc = 0;
   if nc == 0 && isfield(grdecl, 'PERMX' ), nc = numel(grdecl.PERMX ); end
   if nc == 0 && isfield(grdecl, 'PERMY' ), nc = numel(grdecl.PERMY ); end
   if nc == 0 && isfield(grdecl, 'PERMZ' ), nc = numel(grdecl.PERMZ ); end
   if nc == 0 && isfield(grdecl, 'PERMXX'), nc = numel(grdecl.PERMXX); end
   if nc == 0 && isfield(grdecl, 'PERMYY'), nc = numel(grdecl.PERMYY); end
   if nc == 0 && isfield(grdecl, 'PERMZZ'), nc = numel(grdecl.PERMZZ); end

   assert (nc > 0);

   vals = zeros([nc, 1]);
   comp = ones([3, 3]);

   %- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
   % Extract first row [k_{xx}, k_{xy}, k_{xz}] from input data.
   %
   if isfield(grdecl, 'PERMX') || isfield(grdecl, 'PERMXX')
      if isfield(grdecl, 'PERMX')
         vals   = [vals, grdecl.PERMX ];
      else
         vals   = [vals, grdecl.PERMXX];
      end
      comp(1,1) = size(vals,2);
      comp      = setDiagonalComponents(comp, 1, 2, 3);
   end

   if isfield(grdecl, 'PERMXY')
      vals      = [vals, grdecl.PERMXY];
      comp(1,2) = size(vals,2); comp(2,1) = comp(1,2);
   end

   if isfield(grdecl, 'PERMXZ')
      vals      = [vals, grdecl.PERMXZ];
      comp(1,3) = size(vals,2); comp(3,1) = comp(1,3);
   end

   %- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

   % Extract second row [k_{yx}, k_{yy}, k_{yz}] from input data.
   %
   if isfield(grdecl, 'PERMYX')
      vals      = [vals, grdecl.PERMYX];
      comp(2,1) = size(vals,2); comp(1,2) = comp(2,1);
   end

   if isfield(grdecl, 'PERMY') || isfield(grdecl, 'PERMYY')
      if isfield(grdecl, 'PERMY')
         vals   = [vals, grdecl.PERMY ];
      else
         vals   = [vals, grdecl.PERMYY];
      end
      comp(2,2) = size(vals,2);
      comp      = setDiagonalComponents(comp, 2, 3, 1);
   end

   if isfield(grdecl, 'PERMYZ')
      vals      = [vals, grdecl.PERMYZ];
      comp(2,3) = size(vals,2); comp(3,2) = comp(2,3);
   end

   %- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

   % Extract third row [k_{zx}, k_{zy}, k_{zz}] from input data.
   %
   if isfield(grdecl, 'PERMZX')
      vals      = [vals, grdecl.PERMZX];
      comp(3,1) = size(vals,2); comp(1,3) = comp(3,1);
   end

   if isfield(grdecl, 'PERMZY')
      vals      = [vals, grdecl.PERMZY];
      comp(3,2) = size(vals,2); comp(2,3) = comp(3,2);
   end

   if isfield(grdecl, 'PERMZ') || isfield(grdecl, 'PERMZZ')
      if isfield(grdecl, 'PERMZ')
         vals   = [vals, grdecl.PERMZ ];
      else
         vals   = [vals, grdecl.PERMZZ];
      end
      comp(3,3) = size(vals,2);
      comp      = setDiagonalComponents(comp, 3, 1, 2);
   end
end

%--------------------------------------------------------------------------

function c = setDiagonalComponents(c, i, j, k)
   if c(j,j) == 1, c(j,j) = c(i,i); end
   if c(k,k) == 1, c(k,k) = c(i,i); end
end
