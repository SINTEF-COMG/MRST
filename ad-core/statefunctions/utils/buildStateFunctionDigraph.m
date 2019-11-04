function [G, names, category, keep] = buildStateFunctionDigraph(C, names, category, varargin)
    opt = struct('Start', {{}}, ...
                 'Stop', {{}}, ...
                 'Center', {{}}, ...
                 'FilterNames', {names});
    opt = merge_options(opt, varargin{:});

    n = numel(names);
    G = digraph(C, names);
    keep = true(n, 1);
    
    hasStart = ~isempty(opt.Start);
    hasStop = ~isempty(opt.Stop);
    hasCenter = ~isempty(opt.Center);
    
    if hasStop || hasCenter
        D = distances(G);
    end
    
    if hasStart || hasCenter
        Gt = digraph(C', names);
        Dr = distances(Gt);
    end
    
    if hasStart
        keep = keep & filter(Dr, names, opt.FilterNames, opt.Start);
    end
    
    if hasStop
        keep = keep & filter(D, names, opt.FilterNames, opt.Stop);
    end
    
    if hasCenter
        keep = keep & (filter(D,  names, opt.FilterNames, opt.Center) | ...
                       filter(Dr, names, opt.FilterNames, opt.Center));
    end
    keep_ix = find(keep);
    G = G.subgraph(keep_ix); %#ok MATLAB backwards compatibility
    names = names(keep);
    category = category(keep);
end

function keep = filter(D, names, shortnames, targets)
    keep = false(numel(names), 1);
    if ischar(targets)
        targets = {targets};
    end
    for i = 1:numel(targets)
        name = targets{i};
        pos = strcmpi(names, name);
        if ~any(pos)
            pos = strcmpi(shortnames, name);
            if sum(pos) > 1
                % Multiple matches - uh oh. Pick the first one.
                pos = find(pos);
                pos = pos(1);
                warning(['Multiple entries found for %s. Arbitrarily taking %s. ', ...
                         'Does it exist in multiple StateGrouping instances?'], name, names{pos});
            end
        end
        keep = keep | isfinite(D(:, pos));
    end
end