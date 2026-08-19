%% Minimal implementation example

%% Instrument Code
% dummy.m Represents a function that is undergoing refactoring.
% It is already instrumented with `regtest.Checkpoint` probes.
% On their own they should have no effect on the code:

dummy()

%% Refine tests
% Define exactly what is to be saved/restored by the probes,
% and do a `setup` run to create the reference results.

disp('Running setup...')
define_tests();

disp('Generated baseline results:')
ls .regtest

%% Run regression tests
% Does a `test` run, restoring the reference inputs and comparing
% the new outputs to the reference results.

disp('Running tests...')
runtests('test.m')
