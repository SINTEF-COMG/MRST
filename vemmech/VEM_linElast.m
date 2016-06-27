function [uu, extra] = VEM_linElast(G, C, el_bc, load, varargin)
%[uu, extra] = VEM_linElast(G, C, el_bc, load, varargin)
% solve linear elastisity problem using the Virtual Element method. Main
% mechanics solver. Without face degree of freedom. Meant to be run for any
% dimension. 
% 
% SYNOPSIS:
% [uu, extra] = VEM_linElast(C, nu, el_bc, load, varargin)
% 
% OUTPUT
% uu is matrix of size [G.nodes.num, G.griddim] of displacement of nodes
% 
% PARAMETERS:
% G     - Grid structure as described by grid_structure, which all so
%         has the mappings from G = mrstGridWithFullMappings(G). Some options 
%         need G = computeGeometryCalc(G).
% E     - Youngs modulo    (http: //en.wikipedia.org/wiki/Shear_modulus)
% nu    - Poisson's ratio
% el_bc - boundary condition of type struct('disp_bc', [], 'force_bc', [])
% 
% 
% 'pn' / pv - List of 'key' / value pairs for supplying optional parameters.
% The supported options are
% opt = struct('type', 'lorenzo',...       % method for stiffnessmatrix
%              'linsolve', @mldivide,...   % solver
%              'local_assembly', false,... % use local assembly
%              'do_local', false); % local forcecalculation
% 
% COMMENTS:
% For all the solvetypes exept lorenzo the assembly code is for general 
% elastisty tensor in voit's notation:
% http://en.wikipedia.org/wiki/Voigt_notation 
%
% SEE ALSO:
% square_2D_example, convergens_test, plotNodeData, plotGridDeformed
% ------------ 

%{ 
   Copyright 2009 - 2014 SINTEF ICT, Applied Mathematics
%} 

   opt = struct('type'          , 'mrst'                          , ...
                'linsolve'      , @mldivide                       , ...
                'blocksize'     , 30000 - (G.griddim - 2) * 20000 , ...
                'add_operators' , true                            , ...
                'force_method'  , 'dual_grad_type'                , ...
                'alpha_scaling' , 1                               , ...
                'S'             , []                              , ...
                'experimental_scaling' , false                    , ...
                'pressure',[]);
   opt = merge_options(opt, varargin{:});
   opt.add_operators= opt.add_operators && nargout>1;
   if(opt.add_operators)
     [S,extra] = VEM_mrst_vec(G, C, 'blocksize', opt.blocksize, ...
                              'alpha_scaling', opt.alpha_scaling, 'S', opt.S, 'experimental_scaling', opt.experimental_scaling); 
   else
     S = VEM_mrst_vec(G, C, 'blocksize', opt.blocksize, ...
                            'alpha_scaling', opt.alpha_scaling, 'S', opt.S, 'experimental_scaling', opt.experimental_scaling);   
   end
   % recalculate "weights" (all are calculated in the assembly, could be
   % calculated only once).
   if(G.griddim == 2)
      qf_all = G.faces.areas / 2; 
      [qc_all, qcvol] = calculateQF_vec(G); 
   else
      % here one should weight the normal with the subface area
      % N = bsxfun(@rdivide, N, G.faces.areas(faces)); 
      [qc_all, qf_all, qcvol] = calculateQC_vec(G); % #ok
      % qf = bsxfun(@times, N(lfacesnum, :), G.weights.face_nodes(inodes)); 
      % qf = bsxfun(@times, N(lfacesnum, :), qf(inodes)); 
   end
   
   % apply Diriclet boundary conditions
   % if duplication of values exist remove them
   bc = el_bc.disp_bc; 
   [bcnodes, j, i] = unique(bc.nodes);
   if(numel(bcnodes)~=numel(bc.nodes))
      %       warning('boundary conditions have mulitiple definitions')
   end
   u_bc = bc.uu(j, :);
   %%{
   mask = zeros(numel(bcnodes), G.griddim); 
   % use the mask form or
   for k = 1:G.griddim
      mask(:, k) = accumarray(i, bc.mask(:, k), [numel(bcnodes), 1]); 
   end
   mask = mask > 0; 
   %}
   
   

   % find the logical vector to remove Diriclet boundary conditions
   % NB: partial Diriclet boundary conditions in primary direction is allowed
   % for now.
   ndof = G.griddim * G.nodes.num; 
   if(all(mask(:) == true))    
      dirdofs = mcolon(G.griddim * (bcnodes - 1) + 1, G.griddim * (bcnodes - 1) + G.griddim)';
      u_bc = reshape(u_bc', [], 1); 
   else
      dirdofs = mcolon(G.griddim * (bcnodes - 1) + 1, G.griddim * (bcnodes - 1) + G.griddim)'; 
      dirdofs = reshape(dirdofs, G.griddim, []); 
      mm = mask'; 
      ind = find(mm); 
      u_bc = reshape(u_bc', [], 1);
      dirdofs = reshape(dirdofs, [], 1);
      dirdofs = dirdofs(ind); 
      u_bc = u_bc(ind); 
   end
   isdirdofs = false(ndof, 1); 
   isdirdofs(dirdofs) = true; 

   
   %% calulate boundary conditions
   V_dir = nan(ndof, 1); 
   V_dir(isdirdofs) = u_bc(:); 
   V_dir(~isdirdofs) = 0; 
   rhso = -S * V_dir; 

   %% calculate load terms several alternatives, which may lead to different errors in particular for thin long cells
   f = calulateVolumeTerm(G,load, qc_all, qcvol, opt);
%end
   % ---------------
   if(~isempty(opt.pressure))
       div = VEM_div(G); 
       f_pressure = div'*opt.pressure;
   else
       f_pressure = zeros(size(f));
   end
   % add load to right hand side
   rhs = rhso + f + f_pressure;
   % add boundary forces
   if(~isempty(el_bc.force_bc))
       if(numel(el_bc.force_bc.faces) > 0)
           bc       = el_bc;
           bc_force = bc.force_bc;
           bcf      = bc_force;
           
           % find weights 
           faces    = bcf.faces;
           assert(numel(faces)==numel(unique(faces)));
           lnn      = G.faces.nodePos(faces + 1) - G.faces.nodePos(faces);
           inodes   = mcolon(G.faces.nodePos(bcf.faces), G.faces.nodePos(bcf.faces + 1) - 1);
           nodes    = G.faces.nodes(inodes);
           lfacenum = rldecode([1:numel(faces)]', lnn); % #ok% ssert boundary face
           assert(all(sum(G.faces.neighbors(faces, :) == 0, 2) == 1));
           
           % lcells = sum(G.faces.neighbors(faces, :), 2);
           % N = bsxfun(@times, G.faces.normals(faces, :), (2 * (G.faces.neighbors(faces, 1) == lcells) - 1));
           if(G.griddim == 2)
               %qf = qf_all(lfacenum, :);  @@
               qf = qf_all(rldecode(faces(:), lnn), :);
           else
               qf = qf_all(inodes);
           end
           
           % find nodes corresponding to forces
           dofs  = mcolon(G.griddim * (nodes - 1) + 1, G.griddim * (nodes - 1) + G.griddim);
           force = bsxfun(@times, bc_force.force(lfacenum, :), qf);
           % transform to dofs numbering
           % assert(all(isdirdofs(dofs) == 0));
           force = force';
           fbc   = accumarray(dofs', force(:)', [ndof, 1]);
           rhs   = rhs + fbc;
       end
   end
   % reduce degrees of freedom
   rhs = rhs(~isdirdofs);
   A   = S(~isdirdofs, ~isdirdofs);
   A   = (A + A') / 2; % matrix should be symmetric assure, make sure that it is also symmetric
                       % numerically
   x   = opt.linsolve(A, rhs); 
   u   = nan(ndof, 1); 

   u(isdirdofs)  = V_dir(isdirdofs); 
   u(~isdirdofs) = x; 
   uu = reshape(u, G.griddim, [])'; 

   if(nargout == 2)
      extra.A    = A; 
      extra.S    = S; 
      vdiv       = VEM_div(G); 
      extra.disc = struct('A'         , A                        , ...
                          'isdirdofs' , isdirdofs                , ...
                          'rhs'       , rhs                      , ...
                          'V_dir'     , V_dir                    , ...
                          'ovol_div'  , vdiv                     , ...
                          'gradP'     , vdiv(:    , ~isdirdofs)' , ...
                          'div'       , vdiv(:    , ~isdirdofs)  , ...
                          'divrhs'    , vdiv * V_dir); 

   end
   
end

function f = calulateVolumeTerm(G,load, qc_all, qcvol, opt)

% warning('Wrong force method may give strange results for some grids. All should be/(is) convergent')
       %%
    %f = zeros(ndof, 1);
   cells  = [1:G.cells.num]';
   inodes = mcolon(G.cells.nodePos(cells), G.cells.nodePos(cells + 1) - 1');
   nodes  = G.cells.nodes(inodes);  
   switch opt.force_method
       %
       case 'node_force'
           
           % use node-based integration
           
           X      = G.nodes.coords(nodes, :);
           
           % X = mesh.V(mesh.P(k, 2:m + 1), 1:2); % build X with vertex coordinates
           % weights to calculate volume forse term.
           % for 2D the weights are calulatedin G = computeGemoetryCalc(G), but for 3D it has
           % to be done. At the moment they are taken as volume / number of nodes of cell.
           
           %w    = G.weights.cell_nodes(inodes);
           %w =accumarray(G.cells.nodes,qcvol);
           w=qcvol;
           ll   = bsxfun(@times, load(X), w)';
           %dofs = mcolon(G.griddim * (nodes - 1) + 1, G.griddim * (nodes - 1) + G.griddim)';
           %f    = accumarray(dofs(:), ll(:), [ndof, 1]);
           
       case  'cell_force_baric'
           
           % use cell based intgration
           %cells    = [1:G.cells.num]';
           nlc      = G.cells.nodePos(cells + 1) - G.cells.nodePos(cells);
           %inodes   = mcolon(G.cells.nodePos(cells), G.cells.nodePos(cells + 1) - 1');
           %nodes    = G.cells.nodes(inodes);
           
           X    = rldecode(G.cells.centroids(cells, :), nlc);
           lcellnum = rldecode(cells, nlc);
           BB = nan(numel(cells), 1);
           for i = 1:G.griddim
               BB(:, i) = accumarray(lcellnum, G.nodes.coords(nodes, i), [numel(cells), 1]);
           end
           fac  = accumarray(lcellnum, 1, [numel(cells), 1]);
           BB   = bsxfun(@rdivide, BB, fac);
           XB   = X - rldecode(BB, nlc);
           vols = rldecode(G.cells.volumes(cells, :), nlc);
           
           % X = mesh.V(mesh.P(k, 2:m + 1), 1:2); % build X with vertex coordinates
           % weights to calculate volume forse term.
           % for 2D the weights are calulatedin G = computeGemoetryCalc(G), but for 3D it has
           % to be done. At the moment they are taken as volume / number of nodes of cell.
           % w = G.weights.cell_nodes(inodes);
           warning('This has to be checked. What is best way for forces');
           if(G.griddim == 3)
               w = (vols ./ rldecode(nlc, nlc) + sum(qc_all(inodes, :) .* (XB), 2));
           else
               assert(G.griddim == 2)
               w = (vols ./ rldecode(nlc, nlc) + sum(qc_all(inodes, :) .* (XB), 2));
           end
           % strange that symmetry will force all weights to be equal.
           ll   = bsxfun(@times, load(X), w)';
       case 'cell_force'
           
           % cells    = [1:G.cells.num]';
            nlc      = G.cells.nodePos(cells + 1) - G.cells.nodePos(cells);
           % inodes   = mcolon(G.cells.nodePos(cells), G.cells.nodePos(cells + 1) - 1');
           %nodes    = G.cells.nodes(inodes);
           X    = rldecode(G.cells.centroids(cells, :), nlc);
           ll   = bsxfun(@times, load(X), qcvol)';
       case 'dual_grad_type'
           
           % just a try to hack correct do not work, for some cases
           % abs(qca_all(:,3)) seems to be the right weight ???
           %ll   = bsxfun(@times, load(X), qcvol)';
           % need to understand way this is ok/ or of it is ok??
           %cells    = [1:G.cells.num]';
           nlc      = G.cells.nodePos(cells + 1) - G.cells.nodePos(cells);
           %inodes   = mcolon(G.cells.nodePos(cells), G.cells.nodePos(cells + 1) - 1');
           %nodes    = G.cells.nodes(inodes);
           X    = rldecode(G.cells.centroids(cells, :), nlc);
           rel_vec=-(X-G.nodes.coords(nodes,:));
           ll   = bsxfun(@times, load(X), qc_all.*rel_vec)';
       otherwise
           error('No such force  calculation')
   end
   ndof = G.griddim * G.nodes.num; 
   dofs = mcolon(G.griddim * (nodes - 1) + 1, G.griddim * (nodes - 1) + G.griddim)';
   f    = accumarray(dofs(:), ll(:), [ndof, 1]);

end