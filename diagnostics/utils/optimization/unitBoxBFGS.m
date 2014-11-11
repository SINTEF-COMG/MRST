function [v, u, history] = unitBoxBFGS(u0, f, varargin)
opt = struct('gradTol',             1e-3, ...
             'objChangeTol',        1e-4, ...
             'maxIt',               100,   ...
             'lineSearchMaxIt',     10,   ...
             'stepInit',            -1,   ...
             'wolfe1',              1e-3, ...
             'wolfe2',              0.9,  ...
             'safeguardFac',        0.0001, ...  
             'stepIncreaseTol',     10,    ...
             'useBFGS',             true);
opt = merge_options(opt, varargin{:});
step    = opt.stepInit;

% do initial evaluation of objective and gradient:
[v0, g0] = f(u0);
[v,u] = deal(v0,u0);
% if not provided, set initial step 
if step <= 0, step = 1; end

it = 0;
success = false;

% initial Hessian-approximation
Hi = -step*eye(numel(u0));
HiPrev = Hi;

% setup struct for gathering optimization history
history = [];
% name|obj.val.|contr.|norm proj.grad.|ls-step|ls-its|ls-flag|hessian 
history = gatherInfo(history, v0, u0, nan, nan, nan, nan, Hi);

while ~success
    it = it+1;
    % Search direction is along projection of inv(H)*g. If problems occur,
    % Hi might be set to previous, or even to I (worst case)
    [d, Hi] = getSearchDirection(u0, g0, Hi, HiPrev);
    if isempty(d), break; end
    % Perform line-search
    [u, v, g, lsinfo] = lineSearch(u0, v0, g0, d, f, opt);
    
    % Update Hessian approximation
    if opt.useBFGS && lsinfo.flag == 1
        [du, dg] = deal(u-u0, g-g0);
        if abs(du'*dg) > sqrt(eps)*norm(du)*norm(dg)
            HiPrev = Hi;
            r = 1/(du'*dg);
            V = eye(numel(u)) - r*dg*du';
            Hi = V'*Hi*V + r*(du*du');
            %eig(Hi)
        else
            fprintf('Hessian not updated during iteration %d.\n', it)
        end
    end
        
    
    %Check stopping criteria
    pg = max(0, min(1, u+g)) - u;
    success = (it >= opt.maxIt) || (norm(pg,inf) < opt.gradTol) || ...
              (abs(v-v0) < opt.objChangeTol);
    % Update history
    history = gatherInfo(history, v, u, norm(pg,inf), lsinfo.step, ...
                         lsinfo.nits, lsinfo.flag, Hi);
    [u0, v0, g0] = deal(u, v, g);
    plotInfo(10, history)
end
end

function [d, Hi] = getSearchDirection(u0, g0, Hi, HiPrev)
% find search-direaction which is the projection of Hi*g0 restricted to
% controls with non-active box-constaints. Check that direction is
% increasing, if not try HiPrev, if still not increasing, set Hi = I.
cnt = 1;
for k = 1:3
    if k==2
        Hi = HiPrev;
    elseif k==3
        Hi = -1;
    end
    nonActive     = true(size(u0));
    nonActivePrev = false(size(u0));
    while norm(nonActive-nonActivePrev)
        nonActivePrev = nonActive;
        d  = max(0, min(1, u0-nonActive.*(Hi*(g0.*nonActive)) )) - u0;
        nonActive = d~=0;
    end
    if d'*g0 >= 0 % increasing search direction found, exit
        break;
    else
        cnt = cnt+1;
        if cnt == 2
            fprintf('Non-increasing search direction, using previous Hessian approximation.\n')
        else
            fprintf('Non-increasing search direction, resetting Hessian to identity.\n')
        end
    end
end
if d'*g0 < 0
    fprintf('All controls on constraints or function decreasing along gradient\n')
    d = [];
end
end

function hst = gatherInfo(hst, val, u, pg, alpha, lsit, lsfl, hess)   
% name|obj.val.|contr.|norm proj.grad.|ls-step|ls-its 
if isempty(hst)
    hst = struct('val', val, 'u', {u}, 'pg', pg, ...
                 'alpha', alpha, 'lsit', lsit, 'lsfl', lsfl, ...
                 'hess', {hess});
else
    hst.val   = [hst.val  , val  ];
    hst.u     = [hst.u    , {u}  ];
    hst.pg    = [hst.pg   , pg   ];
    hst.alpha = [hst.alpha, alpha];
    hst.lsit  = [hst.lsit , lsit ];
    hst.lsfl  = [hst.lsfl , lsfl ];
    hst.hess  = [hst.hess ,{hess}];
end
end
  
function [] = plotInfo(fig, hst)
figure(fig)
xt = 0:(numel(hst.val)-1);
ch = [0, hst.val(2:end)-hst.val(1:end-1)];
subplot(4,1,1), plot(xt, hst.val, '.-','LineWidth', 2, 'MarkerSize', 20), title('Objective');
subplot(4,1,2), semilogy(xt,hst.pg,'.-','LineWidth', 2, 'MarkerSize', 20), title('Gradient norm');
subplot(4,1,3), semilogy(xt,ch,'.-','LineWidth', 2, 'MarkerSize', 20), title('Objective change');
subplot(4,1,4), bar(xt,hst.lsit), title('Line search iterations')
drawnow
end


    