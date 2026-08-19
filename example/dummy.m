function c = dummy(refactored)
% Example of a function undergoing refactoring
% For illustration purposes, we're simulating two file versions
% using the REFACTORED flag.

arguments
    refactored (1,1) {logical} = false;
end

%% Context (might change during refactoring)

if ~refactored
    a = 6;
    b = 7;
else
    a = 1;
    b = 2;
end

%% Instrumentation Header (inserted before refactoring)

obj = regtest.Checkpoint('dummy_id');  % create/get test definition
obj.do('input');  % save/restore workspace before chunk

%% Code chunk to test (should do the same before and after)

if ~refactored
    c = 0;
    for j = 1:a
        c = c + b;
    end
else
    c = a*b;
end

%% Instrumentation Footer (inserted before refactoring)

obj.do('output'); % save/test workspace after chunk

end
