function define_tests()
% Setup run before refactoring

regtest.Checkpoint.session.reset(true)

%% Where to store results
session = regtest.Checkpoint.session;
mkdir('.regtest');
session.path = '.regtest';

%% Define tests
%
% regtest.Checkpoint('dummy_id') inside the probed function will
% return this test object

obj = regtest.Checkpoint( ...
    'dummy_id', ...                         % test id
    'dummy();', ...                         % document original call
    input={'onlynames', {'a','b'}}, ...     % code block "inputs"
    output={'onlynames', 'c'});             % code block "outputs"

%% Generate reference results

% Run code on 'setup' mode, dump reference results in session.path
obj.state = 'setup';
eval(obj.call);
