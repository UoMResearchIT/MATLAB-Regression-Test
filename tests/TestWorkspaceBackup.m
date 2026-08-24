function tests = TestWorkspaceBackup()
% Tests for regtest.WorkspaceBackup class

    tests = functiontests(localfunctions);
end

function setupOnce(testCase)

    addpath('..');
    testCase.TestData.tmpdir = tempname;
    mkdir(testCase.TestData.tmpdir);
end

function teardownOnce(testCase)

    fclose all;
    if isfolder(testCase.TestData.tmpdir)
        rmdir(testCase.TestData.tmpdir, 's');
    end
end

function test_default_constructor(testCase)

	verifyWarningFree(testCase, @() regtest.WorkspaceBackup);
    verifyInstanceOf(testCase, regtest.WorkspaceBackup(), 'regtest.WorkspaceBackup');
end

function test_set(testCase)

    obj = regtest.WorkspaceBackup();
    verifyWarning(testCase, @() obj.set('verbose',0), 'regtest:WorkspaceBackup:set:nargout');

    obj = obj.set('onlyclasses', {'foo','bar'}, 'skipnames','b');
    verifyEqual(testCase, obj.onlyclasses, ["foo" "bar"]);
    verifyEqual(testCase, obj.skipnames, "b");
end

function test_set_file(testCase)

    obj = regtest.WorkspaceBackup();
    verifyError(testCase, @() obj.set('file', 42), 'regtest:WorkspaceBackup:setfile:name');
    verifyError(testCase, @() obj.set('file', 'foo.bar'), 'regtest:WorkspaceBackup:setfile:ext');

    dirlist = dir();
    dirlist(~[dirlist.isdir]) = [];
    nonexisting = matlab.lang.makeUniqueStrings('nonexistingdir',{dirlist.name});
    verifyError(testCase, @() obj.set('file', fullfile(nonexisting, 'foo.mat')), 'regtest:WorkspaceBackup:setfile:path');

    obj = obj.set('file','foo');
    verifyEqual(testCase, obj.file, 'foo.mat');
end

function [obj, a, b, c, result] = example(testCase, varargin)
% Retrn a test regtest.WorkspaceBackup object, variables to backup, and expected result

    % regtest.WorkspaceBackup object
    obj = regtest.WorkspaceBackup('', 'interactive', 0, varargin{:});
    obj.onlynames = {'a','b','c'};

    if ~contains('file', varargin(1:2:end))
    % "personalize" obj.file, so that it is different for each test
        name = func2str(testCase.TestFcn);
        obj.file = fullfile(testCase.TestData.tmpdir, name);
    end

    % Dummy variables
    a = 1;
    b = 'b';
    c = {3};

    % Expected backup contents (for regtest.WorkspaceBackup below)
    result = cell2struct({a,b,c}',{'a','b','c'});
end

function test_constructor(testCase)
% Just check that setup worked alright

    obj = example(testCase);

    verifyInstanceOf(testCase, regtest.WorkspaceBackup(), 'regtest.WorkspaceBackup');
    verifyEqual(testCase, obj.interactive, false);
end

function test_backup(testCase)
% General backup (including skipnames)

    [obj, a, b, c, result] = example(testCase); %#ok<ASGLU>

    obj.backup();
    verifyTrue(testCase, isfile(obj.file));
    verifyEqual(testCase, load(obj.file), result)
end

function test_dryrun(testCase)

    [obj, a, b, c] = example(testCase); %#ok<ASGLU>
    [x,vars] = obj.backup(1);
    verifyEqual(testCase, x, obj);
    verifyEqual(testCase, vars, ["a","b","c"]');
end

function test_restore(testCase)
% (partial) restore onto workspace

    [obj, a, b, c, result] = example(testCase); %#ok<ASGLU>

    obj.backup();
    x = obj.restore();
    verifyEqual(testCase, x.a, result.a);
end

function test_file_with_spaces(testCase)

    name = fullfile(testCase.TestData.tmpdir, 'file with spaces.mat');
    [obj, a, b, c, result] = example(testCase, 'file', name); %#ok<ASGLU>
    assert(contains(obj.file,' '));
    obj.backup();
    x = obj.restore();
    verifyEqual(testCase, x.a, result.a);
end

function test_restore_on_workspace(testCase)
% (partial) restore onto workspace

    [obj, a, b, c, result] = example(testCase); %#ok<ASGLU>

    obj.backup();
    a = a + 1;
    obj.restore('a');
    verifyEqual(testCase, a, result.a);
end

function test_skipnames(testCase)

    [obj, a, b, c, result] = example(testCase); %#ok<ASGLU>

    obj.skipnames = {'a'}; 
    obj.backup();
    verifyEqual(testCase, obj.restore(), rmfield(result,'a'))
end

function test_onlyclasses(testCase)

    [obj, a, b, c] = example(testCase); %#ok<ASGLU>

    obj.onlyclasses = {'double'}; 
    obj.backup();
    verifyEqual(testCase, obj.restore(), struct('a',a))
end

function test_skipclasses(testCase)

    [obj, a, b, c, result] = example(testCase); %#ok<ASGLU>

    obj.skipclasses = {'cell'}; 
    obj.backup();
    verifyEqual(testCase, obj.restore(), rmfield(result,'c'))
end

function test_base_backup(testCase)
% test backup & restore in 'base'

    % set a dummy variable in base
    varnames = evalin('base','who');
    var = matlab.lang.makeUniqueStrings('foo', varnames);
    assignin('base', var, 42);

    % test backup
    obj = example(testCase, 'workspace','base');
    obj.onlynames = var;
    obj.backup();
    verifyEqual(testCase, obj.restore(), struct(var,42))

    % test restore
    assignin('base', var, 'not_42');
    obj.restore();
    verifyEqual(testCase, evalin('base',var), 42)
end

function test_backup_by_other(testCase)
% test backup by third party

    [obj, a, b, c, result] = example(testCase); %#ok<ASGLU>

    x = third_party(obj);
    verifyEqual(testCase, x, result)
end

function x = third_party(obj)
% Try to backup variables in caller workspace

    assignin('caller','spy', obj);
    evalin('caller','spy.backup');
    x = obj.restore();
end

