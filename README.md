[![tests](https://github.com/UoMResearchIT/MATLAB-Regression-Test/actions/workflows/test_and_release.yaml/badge.svg)](https://github.com/UoMResearchIT/MATLAB-Regression-Test/actions/workflows/test_and_release.yaml)
[![codecov](https://codecov.io/github/UoMResearchIT/MATLAB-Regression-Test/graph/badge.svg)](https://codecov.io/github/UoMResearchIT/MATLAB-Regression-Test)

<img src="resources/spaghetti.png" alt="polaroid snapshot of a plate of spaghetti" width="40%">

# MATLAB Regression Test
Tool to add regression checkpoints to messy code (that can later be turned into unit tests).

This is not meant to be a replacement for well written [Unit Tests](https://uk.mathworks.com/help/matlab/matlab-unit-test-framework.html).
Rather, it is a development tool to refactor code that has little or no tests; to make sure that, as you tidy up the code (and write proper tests) it continues to produce the same outputs.

The idea is to insert minimally invasive "instrumentation probes" into code before refactoring, then do a `setup` run where the probes write snapshots (partial dumps) of the environment at those points.
During and after refactoring, the same probes can be used on `test` mode, to make sure that the new code produces the same results.

## Structure
The package defines three classes:
+   [`regtest.Checkpoint`](+regtest/Checkpoint.m) defines individual _test objects_ (see [Usage](#usage) below)
+   [`regtest.WorkspaceBackup`](+regtest/WorkspaceBackup.m) is a wrapper around [`save`](https://uk.mathworks.com/help/matlab/ref/save.html). It allows `regtest.Checkpoint` to do workspace dumps from the caller environment, with additional options (e.g. to exclude certain classes).
+   [`regtest.Session`](+regtest/Session.m) is used to store a _static_ ([global-like](https://uk.mathworks.com/help/matlab/matlab_oop/static-data.html)) index of test objects. It allows these to be accessed from anywhere in the code, via the structure `regtest.Checkpoint.session.tests`.

## Usage

For a quick start, look at [getting started](./example/getting_started.m) guide in the [example](./example) folder.

### 1. Instrument code

+   Define/retrieve a test object by id: `regtest.Checkpoint('id')`
+   Use `obj.do('input')` and `obj.do('output')` to mark the spots right before and after the code to be tested:

```matlab
function z = instrumented_function(x, y)

    % insert right before code to be tested
    obj = regtest.Checkpoint('test_dummy');
    obj.do('input');

    % Do stuff
    z = dummy(x, y);

    % insert right after code to be tested.
    obj.do('output');
end
```

### 2. Refine tests
    
+   Test objects can include a `call` to document how to reach the test, and `input` and `output` options (`WorkspaceBackup` objects) that define which variables are to be (re)stored before and after the code to be tested.
+   Every test object will be pushed to a static (global) index, as `regtest.Checkpoint.session.tests.(id)`
+   Once a test exists in the index, another call to `regtest.Checkpoint(id)` will return the existing object

```matlab
function define_test_objects()
% Run before instrumented code, to overwrite `regtest.Checkpoint('test_dummy')`

    regtest.Checkpoint('test_dummy', 'instrumented_function()', 'input', {'onlynames', {'x','y'}}, 'output', {'onlynames', 'z'});

end
```

### 2. Do a `'setup'` run

When the `state` flag of a test object `obj` is set to `'setup'`, the test probes:

+   `obj.do('input')` - Will save all reference workspace inputs, into `obj.input.file`.
+   `obj.do('output')` - Will save all reference workspace outputs, into `obj.output.file`.

To generate regression results, set the test state to `setup`, and run the code that contains the probes:

```matlab
obj = regtest.Checkpoint('test_dummy');
obj.state = 'setup';
eval(obj.call);
```

After a successful setup run, the `obj.state` will revert back to `'idle'`.

### 3. Modify the code

While `obj.state == 'idle'`, calls to `obj.do` will not do anything,
you can leave the probes in place while you refactor the code.

### 4. Do a `'test'` run

If the `state` flag of a test object `obj` is set to `test`:

+   `obj.do('input')` - Will **restore** all reference workspace inputs, from `obj.input.file` into the calling workspace.
+   `obj.do('output')` - Will save all test workspace outputs, into **`obj.test_io.file`**.

```matlab
obj = regtest.Checkpoint('test_dummy');
obj.state = 'test';
eval(obj.call);
```

After that, you can compare the contents of `obj.test_io.file` and `obj.output.file`:

```matlab
original = load(obj.output.file);
refactored = load(obj.test_io.file);

% in most cases you might want something more elaborate
assert(isequal(original, refactored))
```

**TODO**: This could be done (semi-)automatically, perhaps generating a test-script similar to [example/test.m](./example/test.m).

### 5. (Optional) reset

Use `regtest.Checkpoint.session.reset(true)` to delete all test objects and their associated files.

