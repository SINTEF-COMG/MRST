function assembly = assembleMPSA(G, prop, loadstruct, eta, tbls, mappings, varargin)
%% Assembly of MPSA-weak
%%
%% Reference paper:
%% Finite volume methods for elasticity with weak symmetry
%% Keilegavlen, Eirik and Nordbotten, Jan Martin
%% International Journal for Numerical Methods in Engineering
%% 2017

    % the solution is given by the system
    %
    % A = [[A11, A12, -D];
    %      [A21, A22,  0];
    %      [D' , 0  ,  0]];
    %
    % u = [u (displacement at nodefacecoltbl);
    %      u (displacement at cellcoltbl);
    %      lagmult (forces in the linear directions at the boundary)];
    %
    % f = [extforce (force at nodefacecoltbl);
    %      force    (volumetric force at cellcoltbl);
    %      bcvals   (for the linear form at the boundary)];
    %
    % A*u = f
    %
    % Note: extforce is sparse and should only give contribution at facets
    % that are at the boundary
    %
    % By construction of the method, the matrix A11 is block-diagonal. Hence,
    % we invert it directly and reduce to a cell-centered scheme.
    
    
    opt = struct('bcetazero'       , true , ...
                 'assemblyMatrices', false, ...
                 'addAdOperators'  , false, ...
                 'extraoutput'     , false);
    opt = merge_options(opt, varargin{:});
    
    % Recover IndexArrays
    coltbl                = tbls.coltbl;
    celltbl               = tbls.celltbl;
    nodetbl               = tbls.nodetbl;
    cellnodetbl           = tbls.cellnodetbl;
    nodefacetbl           = tbls.nodefacetbl;
    cellcoltbl            = tbls.cellcoltbl;
    nodecoltbl            = tbls.nodecoltbl;
    nodefacecoltbl        = tbls.nodefacecoltbl;
    cellnodefacetbl       = tbls.cellnodefacetbl;
    cellnodecoltbl        = tbls.cellnodecoltbl;
    cellnodecolrowtbl     = tbls.cellnodecolrowtbl;
    cellnodefacecoltbl    = tbls.cellnodefacecoltbl;
    cellnodefacecolrowtbl = tbls.cellnodefacecolrowtbl;
    colrowtbl             = tbls.colrowtbl;
    nodecolrowtbl         = tbls.nodecolrowtbl;
    col2row2tbl           = tbls.col2row2tbl;
    cellcol2row2tbl       = tbls.cellcol2row2tbl;
    cellnodecol2row2tbl   = tbls.cellnodecol2row2tbl;
    
    cell_from_cellnode         = mappings.cell_from_cellnode;
    node_from_cellnode         = mappings.node_from_cellnode;
    cellnode_from_cellnodeface = mappings.cellnode_from_cellnodeface;
    nodeface_from_cellnodeface = mappings.nodeface_from_cellnodeface;
    
    % Some shortcuts
    c_num     = celltbl.num;
    n_num     = nodetbl.num;
    cnf_num   = cellnodefacetbl.num;
    cnfc_num  = cellnodefacecoltbl.num;
    cn_num    = cellnodetbl.num;
    cncr_num  = cellnodecolrowtbl.num;
    nf_num    = nodefacetbl.num;
    nfc_num   = nodefacecoltbl.num;
    cnfcr_num = cellnodefacecolrowtbl.num;
    d_num     = coltbl.num;
    
    dim = coltbl.num;

    %% Construction of tensor g (as defined in paper eq 4.1.2)

    g = computeConsistentGradient(G, eta, tbls, mappings, 'bcetazero', opt.bcetazero);

    %% Construction of the gradient operator
    %

    % Construction of gradnodeface_op : nodefacecoltbl -> cellnodecolrowtbl
    %
    % The nodefacecol part of the grad operator from nodefacecoltbl to
    % cellnodecolrowtbl is obtained for any u in nodefacecoltbl by using v =
    % prod.eval(g, u) where prod is defined below
    %
    prod = TensorProd();
    prod.tbl1 = cellnodefacecoltbl;
    prod.tbl2 = nodefacecoltbl;
    prod.tbl3 = cellnodecolrowtbl;
    prod.replacefds2 = {'coldim', 'rowdim'};
    prod.reducefds   = {'faces'};
    prod.mergefds    = {'nodes'};

    prod.pivottbl = cellnodefacecolrowtbl;
    [r, c, i] = ind2sub([d_num, d_num, cnf_num], (1 : cnfcr_num)');
    prod.dispind1 = sub2ind([d_num, cnf_num], c, i);
    prod.dispind2 = sub2ind([d_num, cnf_num], r, nodeface_from_cellnodeface(i));
    prod.dispind3 = sub2ind([d_num, d_num, cn_num], r, c, cellnode_from_cellnodeface(i));
    prod.issetup = true;

    gradnodeface_T = SparseTensor('matlabsparse', true);
    gradnodeface_T = gradnodeface_T.setFromTensorProd(g, prod);

    % Construction of gradcell_T : cellcoltbl -> cellnodecolrowtbl
    %
    % The cellcol part of the grad operator from cellcoltbl to cellnodecolrowtbl is
    % obtained for any u in cellcoltbl by using v = prod.eval(greduced, u)
    % where greduced and prod are defined below 
    %
    map = TensorMap();
    map.fromTbl = cellnodefacecoltbl;
    map.toTbl = cellnodecoltbl;
    map.mergefds = {'cells', 'nodes', 'coldim'};

    map.pivottbl = cellnodefacecoltbl;
    map.dispind1 = (1 : cnfc_num)';
    [c, i] = ind2sub([d_num, cnf_num], (1 : cnfc_num)');
    map.dispind2 = sub2ind([d_num, cn_num], c, cellnode_from_cellnodeface(i));
    map.issetup = true;

    % note minus sign
    greduced = - map.eval(g);

    prod = TensorProd();
    prod.tbl1 = cellnodecoltbl;
    prod.tbl2 = cellcoltbl;
    prod.tbl3 = cellnodecolrowtbl;
    prod.replacefds2 = {'coldim', 'rowdim'};
    prod.mergefds = {'cells'};

    prod.pivottbl = cellnodecolrowtbl;
    [r, c, i] = ind2sub([d_num, d_num, cn_num], (1 : cncr_num)');
    prod.dispind1 = sub2ind([d_num, cn_num], c, i);
    prod.dispind2 = sub2ind([d_num, c_num], r, cell_from_cellnode(i));
    prod.dispind3 = (1 : cncr_num);
    prod.issetup = true;

    gradcell_T = SparseTensor('matlabsparse', true);
    gradcell_T = gradcell_T.setFromTensorProd(greduced, prod);

    %% Construction of the divergence operator
    %
    % setup the facet normals
    
    facetNormals = computeFacetNormals(G, cellnodefacetbl);

    % divnodeface_T : cellnodecolrowtbl -> nodefacecoltbl
    %
    % The nodefacecol part of the divergence operator from cellnodecolrowtbl to
    % nodefacecoltbl is obtained for any u in cellnodecolrowtbl by evaluating the
    % expression divnodeface_T.eval(d, u) where d and divnodeface_T are defined
    % below
    %
    d = facetNormals; 
    prod = TensorProd();
    prod.tbl1 = cellnodefacecoltbl;
    prod.tbl2 = cellnodecolrowtbl;
    prod.replacefds1 = {'coldim', 'rowdim'};
    prod.replacefds2 = {'coldim', 'rowdim', 'interchange'};
    prod.reducefds = {'rowdim', 'cells'};
    prod.mergefds = {'nodes'};
    prod.tbl3 = nodefacecoltbl;

    prod.pivottbl = cellnodefacecolrowtbl;
    [r, c, i] = ind2sub([d_num, d_num, cnf_num], (1 : cnfcr_num)');
    prod.dispind1 = sub2ind([d_num, cnf_num], r, i);
    prod.dispind2 = sub2ind([d_num, d_num, cn_num], c, r, cellnode_from_cellnodeface(i));
    prod.dispind3 = sub2ind([d_num, nf_num], c, nodeface_from_cellnodeface(i));
    prod.issetup = true;

    divnodeface_T = SparseTensor('matlabsparse', true);
    divnodeface_T = divnodeface_T.setFromTensorProd(d, prod);

    % divcell_T : cellnodecolrowtbl -> cellcoltbl
    %
    % the cellcol part of the divergence operator from cellnodecolrowtbl to
    % cellcoltbl is obtained for any u in cellnodecolrowtbl by evaluating the
    % expression divcell_T.eval(dreduced, u) where dreduced and divcell_T
    % are defined below
    %

    fds = {'cells', 'nodes', 'coldim'};
    % note the minus sign below (see formula in paper)
    map = TensorMap();
    map.fromTbl = cellnodefacecoltbl;
    map.toTbl = cellnodecoltbl;
    map.mergefds = {'cells', 'nodes', 'coldim'};
    map.pivottbl = cellnodefacecoltbl;
    
    map.dispind1 = (1 : cnfc_num)';
    [c, i] = ind2sub([d_num, cnf_num], (1 : cnfc_num)');
    map.dispind2 = sub2ind([d_num, cn_num], c, cellnode_from_cellnodeface(i));
    map.issetup = true;
    
    dreduced = - map.eval(facetNormals);

    prod = TensorProd();
    prod.tbl1 = cellnodecoltbl;
    prod.tbl2 = cellnodecolrowtbl;
    prod.tbl3 = cellcoltbl;
    prod.replacefds1 = {'coldim', 'rowdim'};
    prod.replacefds2 = {'coldim', 'rowdim', 'interchange'};
    prod.reducefds   = {'rowdim', 'nodes'};
    prod.mergefds    = {'cells'};

    prod.pivottbl = cellnodecolrowtbl;
    [r, c, i] = ind2sub([d_num, d_num, cn_num], (1 : cncr_num)');
    prod.dispind1 = sub2ind([d_num, cn_num], r, i);
    prod.dispind2 = sub2ind([d_num, d_num, cn_num], c, r, i);
    prod.dispind3 = sub2ind([d_num, c_num], c, cell_from_cellnode(i));
    prod.issetup = true;

    divcell_T = SparseTensor('matlabsparse', true);
    divcell_T = divcell_T.setFromTensorProd(dreduced, prod);


    %% Construction of transpose operator for matrices at nodes (that are
    %% elements of nodecolrowtbl)
    %
    %  trans_T: nodecolrowtbl -> nodecolrowtbl

    symcol2row2tbl.coldim2 = colrowtbl.get('coldim');
    symcol2row2tbl.rowdim2 = colrowtbl.get('rowdim');
    symcol2row2tbl.coldim1 = colrowtbl.get('rowdim');
    symcol2row2tbl.rowdim1 = colrowtbl.get('coldim');
    symcol2row2tbl = IndexArray(symcol2row2tbl);

    prod = TensorProd();
    prod.tbl1 = symcol2row2tbl;
    prod.tbl2 = nodecolrowtbl;
    prod.tbl3 = nodecolrowtbl;
    prod.replacefds1 = {{'coldim1', 'coldim'}, ...
                        {'rowdim1', 'rowdim'}};
    prod.replacefds2 = {{'coldim', 'coldim2'}, ...
                        {'rowdim', 'rowdim2'}};
    prod.reducefds = {'coldim2', 'rowdim2'};

    symnodecol2row2tbl = crossIndexArray(nodetbl, symcol2row2tbl, {});
    nc2r2_num = symnodecol2row2tbl.num; % shortcut

    % (note the definition of symcol2row2tbl above)
    prod.pivottbl = symnodecol2row2tbl;
    [r, c, i] = ind2sub([d_num, d_num, n_num], (1 : nc2r2_num)');
    c2 = c;
    r2 = r;
    c1 = r;
    r1 = c;
    prod.dispind1 = sub2ind([d_num, d_num], r, c);
    prod.dispind2 = sub2ind([d_num, d_num, n_num], r2, c2, i);
    prod.dispind3 = sub2ind([d_num, d_num, n_num], r1, c1, i);
    prod.issetup = true;

    trans_T = SparseTensor('matlabsparse', true);
    trans_T = trans_T.setFromTensorProd(ones(symcol2row2tbl.num, 1), prod);

    %% Construction of nodal average for cellnode tensor
    %
    % transnodeaverage_T : cellnodecolrowtbl -> nodecolrowtbl
    %
    % (later this operator is dispatched to cells)
    %

    % Compute number of cell per node
    map = TensorMap();
    map.fromTbl = cellnodetbl;
    map.toTbl = nodetbl;
    map.mergefds = {'nodes'};
    map = map.setup();
    
    nnodepercell = map.eval(ones(cellnodetbl.num, 1));
    
    map = TensorMap();
    map.fromTbl = nodetbl;
    map.toTbl = cellnodetbl;
    map.mergefds = {'nodes'};
    map = map.setup();
    
    coef = map.eval(1./nnodepercell);

    % We eliminitate the places (at the boundaries) where the local reconstruction
    % is ill-posed: nodes with one cell in 2d (corners of a Cartesian grid) and
    % nodes with less the two nodes in 3d (edges of a Cartesian grid);

    switch dim
      case 2
        maxnnodepercell = 1;
      case 3
        maxnnodepercell = 2;
    end
    
    fixnodetbl.nodes = find(nnodepercell <= maxnnodepercell);
    fixnodetbl = IndexArray(fixnodetbl);
    
    dobcfix = true;
    if dobcfix
        coef(coef >= 1/maxnnodepercell) = 0;
    end

    prod = TensorProd();
    prod.tbl1 = cellnodetbl;
    prod.tbl2 = cellnodecolrowtbl;
    prod.tbl3 = nodecolrowtbl;
    prod.reducefds = {'cells'};
    prod.mergefds = {'nodes'};

    prod.pivottbl = cellnodecolrowtbl;
    [r, c, i] = ind2sub([d_num, d_num, cn_num], (1 : cncr_num)');
    prod.dispind1 = i;
    prod.dispind2 = (1 : cncr_num)';
    prod.dispind3 = sub2ind([d_num, d_num, n_num], r, c, node_from_cellnode(i));
    prod.issetup = true;

    nodeaverage_T = SparseTensor('matlabsparse', true);
    nodeaverage_T = nodeaverage_T.setFromTensorProd(coef, prod);

    transnodeaverage_T = trans_T*nodeaverage_T;
    % transnodeaverage_T = nodeaverage_T;
    
    % We need to dispatch this tensor to cellnodecolrowtbl.
    % Now we have
    % transnodeaverage_T : cellnodecolrowtbl -> cellnodecolrowtbl

    map = TensorMap();
    map.fromTbl = nodecolrowtbl;
    map.toTbl = cellnodecolrowtbl;
    map.mergefds = {'nodes', 'coldim', 'rowdim'};
    
    map.pivottbl = cellnodecolrowtbl;
    [r, c, i] = ind2sub([d_num, d_num, cn_num], (1 : cncr_num)');
    map.dispind1 = sub2ind([d_num, d_num, n_num], r, c, node_from_cellnode(i));
    map.dispind2 = (1 : cncr_num)';
    map.issetup = true;

    celldispatch_T = SparseTensor('matlabsparse', true);
    celldispatch_T = celldispatch_T.setFromTensorMap(map);

    transnodeaverage_T = celldispatch_T*transnodeaverage_T;

    %% We need to multiply by 2 at the place where we discarded the symmetry requirement

    coef = ones(nodetbl.num, 1);
    coef(fixnodetbl.get('nodes')) = 2;

    map = TensorMap();
    map.fromTbl = nodetbl;
    map.toTbl = cellnodecolrowtbl;
    map.mergefds = {'nodes'};
    
    map.pivottbl = cellnodecolrowtbl;
    [r, c, i] = ind2sub([d_num, d_num, cn_num], (1 : cncr_num)');
    map.dispind1 = node_from_cellnode(i);
    map.dispind2 = (1 : cncr_num)';
    map.issetup = true;
    
    coef = map.eval(coef);

    prod = TensorProd();
    prod.tbl1 = cellnodecolrowtbl;
    prod.tbl2 = cellnodecolrowtbl;
    prod.mergefds = {'cells', 'nodes', 'coldim', 'rowdim'};
    prod.tbl3 = cellnodecolrowtbl;

    prod.pivottbl = cellnodecolrowtbl;
    cncr_num = cellnodecolrowtbl.num; %shortcut
    prod.dispind1 = (1 : cncr_num)';
    prod.dispind2 = (1 : cncr_num)';
    prod.dispind3 = (1 : cncr_num)';
    prod.issetup = true;

    bcfix_T = SparseTensor('matlabsparse', true);
    bcfix_T = bcfix_T.setFromTensorProd(coef, prod);


    %% Construction of the stiffness operator
    %
    % C_T : cellnodecolrowtbl -> cellnodecolrowtbl
    %

    C = setupStiffnessTensor(prop, tbls);

    map = TensorMap();
    map.fromTbl = cellcol2row2tbl;
    map.toTbl = cellnodecol2row2tbl;
    map.mergefds = {'cells', 'coldim1', 'coldim2', 'rowdim1', 'rowdim2'};
    
    map.pivottbl = cellnodecol2row2tbl;
    cnc2r2_num = cellnodecol2row2tbl.num; %shortcut
    c2r2_num = col2row2tbl.num; %shortcut
    [c2r2, i] = ind2sub([c2r2_num, cn_num], (1 : cnc2r2_num)');
    map.dispind1 = sub2ind([c2r2_num, c_num], c2r2, cell_from_cellnode(i));
    map.dispind2 = (1 : cnc2r2_num)';
    map.issetup = true;
    
    C = map.eval(C);
    
    prod = TensorProd();
    prod.tbl1 = cellnodecol2row2tbl;
    prod.tbl2 = cellnodecolrowtbl;
    prod.replacefds1 = {{'coldim1', 'coldim'}, {'rowdim1', 'rowdim'}};
    prod.replacefds2 = {{'coldim', 'coldim2'}, {'rowdim', 'rowdim2'}};
    prod.mergefds = {'cells', 'nodes'};
    prod.reducefds = {'coldim2', 'rowdim2'};
    prod.tbl3 = cellnodecolrowtbl;

    prod.pivottbl = cellnodecol2row2tbl;

    d = d_num; %shortcut
    [r2, c2, r1, c1, i] = ind2sub([d, d, d, d, cn_num], (1 : cnc2r2_num)');
    prod.dispind1 = (1 : cnc2r2_num)';
    prod.dispind2 = sub2ind([d, d, cn_num], r1, c1, i);
    prod.dispind3 = sub2ind([d, d, cn_num], r2, c2, i);
    prod.issetup = true;

    C_T = SparseTensor('matlabsparse', true);
    C_T = C_T.setFromTensorProd(C, prod);

    %% Assembly
    
    if dobcfix
        Cgradnodeface_T = bcfix_T*C_T*gradnodeface_T;
    else
        Cgradnodeface_T = C_T*gradnodeface_T;
    end
    
    transaverCgradnodeface_T = transnodeaverage_T*Cgradnodeface_T;

    combCgradnodeface_T = 0.5*(Cgradnodeface_T + transaverCgradnodeface_T);
    
    if dobcfix
        Cgradcell_T = bcfix_T*C_T*gradcell_T;
    else
        Cgradcell_T = C_T*gradcell_T;
    end
    
    transaverCgradcell_T = transnodeaverage_T*Cgradcell_T;

    combCgradcell_T = 0.5*(Cgradcell_T + transaverCgradcell_T);
    
    debug = false;
    if debug
        C1 = combCgradnodeface_T.getMatrix();
        C2 = combCgradcell_T.getMatrix();
    end        
    
    A11 = divnodeface_T*combCgradnodeface_T;
    A12 = divnodeface_T*combCgradcell_T; 
    A21 = divcell_T*combCgradnodeface_T;
    A22 = divcell_T*combCgradcell_T; 

    A11 = A11.getMatrix();
    A12 = A12.getMatrix();
    A21 = A21.getMatrix();
    A22 = A22.getMatrix();
    
    % Uses the block structure for the local reduction
    % We count the number of degrees of freedom that are connected to the same
    % node.
    [nodes, sz] = rlencode(nodefacecoltbl.get('nodes'), 1);
    opt.invertBlocks = 'mex';
    bi = blockInverter(opt);
    invA11 = bi(A11, sz);


    % We enforce the boundary conditions as Lagrange multipliers

    bc = loadstruct.bc;
    if ~isfield(bc, 'bcnodefacetbl')
        bc = setupFaceBC(bc, G, tbls);
    end
    [D, bcvals] = setupNodeFaceBc(bc, G, tbls);
    
    %  We scale the constraint equation for the boundary conditions
    fac    = max(max(abs(A11)));
    D      = fac*D;
    bcvals = fac*bcvals;
    
    extforce = loadstruct.extforce;
    force = loadstruct.force;

    fullrhs{1} = extforce;
    fullrhs{2} = force;
    fullrhs{3} = bcvals;
    
    matrices = struct('A11', A11, ...
                      'A12', A12, ...
                      'A21', A21, ...
                      'A22', A22, ...
                      'D'  , D  , ...
                      'invA11', invA11);
    matrices.fullrhs = fullrhs;
    
    % We reduced the system (shur complement) using invA11
    % We obtain system of the form
    %
    % B*u = rhs
    %
    % where
    %
    % B = [[B11, B12];
    %      [B21, B22]];
    %
    % u = [u (displacement at cellcoltbl);
    %      lagmult];
    %
    % rhs = [-A21*invA11*extforce;  +  [force;
    %        -D'*invA11*extforce  ]     bcvals]
    
    B11 = A22 - A21*invA11*A12;
    B12 = A21*invA11*D;
    B21 = -D'*invA11*A12;
    B22 = D'*invA11*D;
    
    B = [[B11, B12]; ...
         [B21, B22]];
    
    adrhs{1} = -A21*invA11*extforce + force; 
    adrhs{2} = -D'*invA11*extforce + bcvals;
    
    rhs = vertcat(adrhs{:});

    % Assembly of operator to compute u_{nodefacecoltbl} from solution of the system
    % (which consists of the concatenation of u_{cellcol} and lagmult) and
    % extforce which is a force in nodefacecoltbl
    %
    % We have  u_{nodefacecoltbl} = R1*sol + R2*extforce
    %
    % where R1 = invA11*[-A12, D] and R2 = invA11
    
    R1 = invA11*[-A12, D];
    R2 = invA11;
    
    % The divergence operator (integrated over the volume)
    % is given by 
    %
    %  div[c] = sum (m[f,s] u_[f,n,i] n[c,f,i])
    %
    % where u:solution, n:normal, m:area
    % indices : c:cell, f:face, n:node.
    
    % The facetNormals are already weighted with respect to area
    
    prod = TensorProd();
    prod.tbl1 = cellnodefacecoltbl;
    prod.tbl2 = nodefacecoltbl;
    prod.tbl3 = celltbl;
    prod.reducefds = {'faces', 'nodes', 'coldim'};
    % prod = prod.setup();
    
    prod.pivottbl = cellnodefacecoltbl;
    prod.dispind1 = (1 : cnfc_num)';
    [c, i] = ind2sub([d_num, cnf_num], (1 : cnfc_num)');
    prod.dispind2 = sub2ind([d_num, nf_num], c, nodeface_from_cellnodeface(i));
    prod.dispind3 = cell_from_cellnode(cellnode_from_cellnodeface(i));
    prod.issetup = true;
    
    div_T = SparseTensor;
    div_T = div_T.setFromTensorProd(facetNormals, prod);
    div = div_T.getMatrix();
    
    
    assembly = struct('B'       , B       , ...
                      'rhs'     , rhs     , ...
                      'g'       , g       , ...
                      'extforce', extforce, ...
                      'R1'      , R1      , ...
                      'R2'      , R2);
    
    if opt.assemblyMatrices
        assembly.matrices = matrices;
    end
    
    
    if opt.addAdOperators
        
        adB = cell(2, 2);
        adB{1, 1} = B11;
        adB{2, 1} = B21;
        adB{1, 2} = B12;
        adB{2, 2} = B22;
        
        % Setup divergence operator (dilatation)
        divop = @(sol) mpsaDivOperator(sol, extforce, R1, R2, div);
        
        % Setup node face displacement operator
        fndisp{1} = -invA11*A12;
        fndisp{2} = invA11*D;
        fndispop = @(u, lm) facenodedispopFunc(u, lm, extforce, fndisp);
        
        % Setup stress operator
        aver = averageop(tbls, mappings);
        stress{1} = combCgradnodeface_T.getMatrix();
        stress{2} = combCgradcell_T.getMatrix();
        stressop = @(unf, uc) stressopFunc(unf, uc, stress, aver);
        
        adoperators.B     = adB;
        adoperators.rhs   = adrhs;        
        adoperators.divop = divop;
        adoperators.facenodedispop = fndispop;
        adoperators.stressop = stressop;
        
        assembly.adoperators = adoperators;
        
    end
        
    if opt.extraoutput
        assembly.divop = @(sol) mpsaDivOperator(sol, extforce, R1, R2, div);
    end
    
end

function fndisp = facenodedispopFunc(u, lm, extforce, fndisp)
    fndisp = fndisp{1}*u + fndisp{2}*lm + extforce;
end


function stress = stressopFunc(unf, uc, stress, aver)
    
    % get stress at each cell-node region (corner)
    stress = stress{1}*unf + stress{2}*uc;
    stress = aver*stress;
    
end

function aver = averageop(tbls, mappings)

    cellnodecolrowtbl = tbls.cellnodecolrowtbl;
    cellcolrowtbl = tbls.cellcolrowtbl;
    cellnodetbl = tbls.cellnodetbl;
    celltbl = tbls.celltbl;
    coltbl = tbls.coltbl;
    
    cell_from_cellnode = mappings.cell_from_cellnode;
    
    % shortcuts
    d_num = coltbl.num;
    c_num = celltbl.num;
    cn_num = cellnodetbl.num;
    cncr_num = cellnodecolrowtbl.num;
    
    % Compute number of nodes per cells
    map = TensorMap();
    map.fromTbl = cellnodetbl;
    map.toTbl = celltbl;
    map.mergefds = {'cells'};
    map = map.setup();
    
    nnodepercell = map.eval(ones(cellnodetbl.num, 1));
    
    % Compute cell average stress
    prod = TensorProd();
    prod.tbl1 = celltbl;
    prod.tbl2 = cellnodecolrowtbl;
    prod.tbl3 = cellcolrowtbl;
    prod.mergefds = {'cells'};
    
    prod.pivottbl = cellnodecolrowtbl;
    [r, c, i] = ind2sub([d_num, d_num, cn_num], (1 : cncr_num)');
    prod.dispind1 = cell_from_cellnode(i);
    prod.dispind2 = (1 : cncr_num)';
    prod.dispind3 = sub2ind([d_num, d_num, c_num], r, c, cell_from_cellnode(i));
    prod.issetup = true;

    aver_T = SparseTensor();
    aver_T = aver_T.setFromTensorProd(1./nnodepercell, prod);

    aver = aver_T.getMatrix();
    
end