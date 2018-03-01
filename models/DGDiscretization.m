classdef DGDiscretization < WENODiscretization
    
    properties
        degree
        basis
        dofPos
        limiter
%         cellIntegrator
%         faceIntegrator
    end
    
    methods
        %-----------------------------------------------------------------%
        function disc = DGDiscretization(model, dim, varargin)
            
            disc = disc@WENODiscretization(model, dim, 'interpolateReference', false);
            
            disc.degree  = 1;
            disc.basis   = 'legendre';
            disc.limiter = 'tvb';
            disc         = merge_options(disc, varargin{:});
            
%             disc.basis = DGBasisFunctions(disc.G, disc.degree);
            
            disc.basis   = dgBasis(disc.G.griddim, disc.degree, disc.basis);
            
            disc.dofPos = reshape((1:disc.G.cells.num*disc.basis.nDof)', disc.basis.nDof, []);
            
            disc.limiter = dgLimiter(disc     , disc.limiter);
            
%             [x, w, nq, ii, jj, cellNo] = makeCellIntegrator(disc.G, (1:disc.G.cells.num)', disc.degree*2);
%             disc.cellIntegrator = struct('points'  , x     , ...
%                                          'wheights', w     , ...
%                                          'numPts'  , nq    , ...
%                                          'ii'      , ii    , ...
%                                          'jj'      , jj    , ...
%                                          'cellNo'  , cellNo);
%                                      
%             [x, w, nq, ii, jj, cellNo, faceNo] = makeFaceIntegrator(disc.G, (1:disc.G.cells.num)', disc.degree);
%             disc.faceIntegrator = struct('points'  , x     , ...
%                                          'wheights', w     , ...
%                                          'numPts'  , nq    , ...
%                                          'ii'      , ii    , ...
%                                          'jj'      , jj    , ...
%                                          'cellNo'  , cellNo, ...
%                                          'faceNo'  , faceNo);
            
        end
        
        %-----------------------------------------------------------------%
        function [xhat, translation, scaling] = transformCoords(disc, x, cells)
            
            G = disc.G;
            translation = -G.cells.centroids(cells,:);
            if isfield(G.cells, 'dx')
                scaling = 1./(G.cells.dx(cells,:)/2);
            else
                scaling = 1./(G.cells.diameters(cells)/(2*sqrt(G.griddim)));
            end
            
            xhat = (x + translation).*scaling;
               
        end
        
        %-----------------------------------------------------------------%
        function ix = getDofIx(disc, dofNo, cells)
            
%             if size(cells,2) == 1
%                 cells = cells';
%             end
%             if size(dofNo,1) == 1
%                 dofNo = dofNo';
%             end
%             
%             nDof = disc.basis.nDof;
%             ix = reshape((cells-1)*nDof + dofNo, [], 1);
              ix = disc.dofPos(dofNo, cells);
              ix = ix(:);
        end
            
        
        %-----------------------------------------------------------------%
        function s = evaluateSaturation(disc, x, cells, dof)
            
            psi  = disc.basis.psi;
            nDof = disc.basis.nDof;
            
            s = 0;
            for dofNo = 1:nDof
                ix = disc.getDofIx(dofNo, cells);
                s = s + dof(ix).*psi{dofNo}(x);
            end
            
        end
        
        %-----------------------------------------------------------------%
        function state = getCellSaturation(disc, state)
            
            [x, w, nq, ii, jj, cellNo] = makeCellIntegrator(disc.G, (1:disc.G.cells.num)', disc.degree);
            W = sparse(ii, jj, w);

            x = disc.transformCoords(x, cellNo);
            
            sdof = state.sdof;
            nPh = size(sdof,2);
            s = zeros(disc.G.cells.num, nPh);
            for phNo = 1:nPh
                s(:,phNo) = (W*disc.evaluateSaturation(x, cellNo, sdof(:,phNo)))./disc.G.cells.volumes;
            end
            
            state.s = s;
            
        end
        
        %-----------------------------------------------------------------%
        function I = cellInt(disc, integrand, cells)
        
            G    = disc.G;
            psi  = disc.basis.psi;
            nDof = disc.basis.nDof;
            
            [x, w, nq, ii, jj, cellNo] = makeCellIntegrator(G, cells, disc.degree+1);
            W = sparse(ii, jj, w);
            
            [x, ~, ~] = disc.transformCoords(x, cellNo);
            
            I = integrand(repmat([0,0], numel(cells).*nDof, 1), ones(numel(cells)*nDof, 1), 1);
            for dofNo = 1:nDof
                ix = disc.getDofIx(dofNo, (1:numel(cells))');
                p = psi{dofNo}(x);
                I(ix) = W*integrand(x, cellNo, p);
            end
            
        end
        
        %-----------------------------------------------------------------%
        function I = cellIntDiv(disc, integrand, cells)
            
            G        = disc.G;
            grad_psi = disc.basis.grad_psi;
            nDof     = disc.basis.nDof;
            
            [x, w, nq, ii, jj, cellNo] = makeCellIntegrator(G, cells, disc.degree+1);
            W = sparse(ii, jj, w);
            
            [x, ~, scaling] = disc.transformCoords(x, cellNo);
            
            I = integrand(repmat([0,0], numel(cells)*nDof, 1), ones(numel(cells)*nDof, 1), [1,1]);
            for dofNo = 1:nDof
                ix = disc.getDofIx(dofNo, (1:numel(cells))');
                gp = grad_psi{dofNo}(x).*scaling;
                I(ix) = W*(integrand(x, cellNo, gp));
            end
            
        end
        
        %-----------------------------------------------------------------%
        function I = faceIntDiv(disc, integrand, cells, upc)
            
            G        = disc.G;
            psi      = disc.basis.psi;
            nDof     = disc.basis.nDof;

            [x, w, nq, ii, jj, cellNo, faceNo] = makeFaceIntegrator(G, cells, disc.degree+1);
            W = sparse(ii, jj, w);

            upCells_v = G.faces.neighbors(:,2);
            intf      = find(disc.internalConn);
            upCells_v(intf(upc)) = disc.N(upc,1);
            upCells_v = upCells_v(faceNo);    
            upCells_G = upCells_v;
            
            [x_c, ~, ~] = disc.transformCoords(x, cellNo);
            [x_v, ~, ~] = disc.transformCoords(x, upCells_v);
            [x_G, ~, ~] = disc.transformCoords(x, upCells_G);
            
            x0 = repmat([0,0], G.cells.num.*nDof, 1);
            [c0, f0] = deal(ones(G.cells.num*nDof, 1));
            I = integrand(x0, x0, x0, c0, c0, c0, f0, 1);
            for dofNo = 1:nDof
                ix = disc.getDofIx(dofNo, (1:numel(cells))');
                p = psi{dofNo}(x_c);
                I(ix) = W*(integrand(x_c, x_v, x_G, cellNo, upCells_v, upCells_G, faceNo, p));
            end
            
        end        
        
    end
        
end