function tests = test()
% Regression tests during/after refactoring

    tests = functiontests(localfunctions);
end

function setupOnce(testCase)

    session = regtest.Checkpoint.session;
    session.restore('.regtest');
    testCase.TestData.session = session;
end

function testDummy(testCase)
% Run "refactored" function in test mode

    obj = testCase.TestData.session.tests.dummy_id;
    obj.state = 'test';

    dummy(1);
    
    original = load(obj.output.file);
    refactored = load(obj.test_io.file);

    testCase.verifyEqual(original, refactored)
end