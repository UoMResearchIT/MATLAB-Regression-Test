classdef Checkpoint < handle
% regtest.Checkpoint - Tool to add automatic checkpoints to messy code (that can later be turned into unit tests).
% See README.md for design use-case.

    properties
        id char {mustBeTextScalar} % unique test identifyer
        call (1,:) string % code to run to get from input to output
        input regtest.WorkspaceBackup % Dump settings before call (regtest.WorkspaceBackup object, or cell-array of arguments for its construction) 
        output regtest.WorkspaceBackup % Dump settings after call (regtest.WorkspaceBackup object, or cell-array of arguments for its construction)
        state char {mustBeTextScalar, mustBeMember(state, {'','idle', 'setup','test'})} % See regtest.Checkpoint.do
        spyname char {mustBeTextScalar, mustBeValidVariableNameOrEmpty} = '' % name of regtest.WorkspaceBackup object, when copied onto 'caller'
    end

    properties(Dependent)
        test_io % a copy of output, with a different file name
    end

    properties(Constant)
        session (1,1) regtest.Session = regtest.Session() % defines default test-path, state, and index of tests
    end

    properties(Constant, Hidden)
        DEF_SPYNAME char {mustBeValidVariableName} = 'CheckpointIO'
    end

    methods (Hidden)
        function name = filename(obj, type)
            mustBeMember(type, {'input','output','test'});
            name = fullfile(regtest.Checkpoint.session.path, [obj.id '_' type '.mat']);
        end
    end
    
    methods
        function obj = Checkpoint(id, call, opts)
        % regtest.Checkpoint(ID, CALL, ...)
        % regtest.Checkpoint(.., 'input', {<args>}) - provide optional arguments to regtest.WorkspaceBackup constructors

            arguments
                id char {mustBeTextScalar, mustBeValidVariableName}
                call (1,:) string {mustBeText} = ""
                opts.input (1,:) cell = {}
                opts.output (1,:) cell = {}
                opts.state char {mustBeTextScalar, mustBeMember(opts.state, {'idle', 'setup','test'})} = 'idle'
                opts.spyname char {mustBeValidVariableNameOrEmpty} = ''
            end

            if ismember(id, obj.session.ids) && nargin == 1
                obj = obj.session.tests.(id);
                return
            end

            obj.id = id;
            obj.call = call;
            
            obj.input = regtest.WorkspaceBackup(obj.filename('input'), 'interactive', 0, opts.input{:});
            obj.output = regtest.WorkspaceBackup(obj.filename('output'), 'interactive', 0, opts.output{:});

            obj.spyname = opts.spyname;
            obj.state = opts.state;

            % Register test in session.index
            obj.session.push(obj);
        end

        function wsb = get.test_io(obj)
            wsb = obj.output.set('file', obj.filename('test'));
        end

        function do(obj, stage)
        % When recording tests (OBJ.state == 'setup'):
        %
        %   OBJ.DO('input') - run OBJ.input.backup in caller workspace (save state before call)
        %   OBJ.DO('output') - run OBJ.output.backup in caller workspace (save state after call)*
        %
        % When running tests (obj.state == 'test'):
        %
        %   OBJ.DO('input') - do OBJ.input.restore in caller workspace (restore state before call)
        %   OBJ.DO('output') - do OBJ.output.backup in caller workspace (save test output after call)*
        %
        % When idle (OBJ.state == 'idle'): do nothing

            if strcmp(obj.state,'idle'), return; end
            assert(~isempty(obj.state), 'OBJ.state cannot be empty');
            
            % get relevant WorkspaceBackup object
            mustBeTextScalar(stage); 
            mustBeMember(stage,{'input','output'});

            switch obj.state
            case 'setup'
            % [input/output].backup in caller workspace

                if strcmp(stage,'output') && ~isfile(obj.input.file)
                    warning('regtest:Checkpoint:do:order', 'Writing checkpoint output before input'); 
                end
                io = obj.(stage); 
                todo = '.backup';

            case 'test'
                switch stage
                case 'input'
                % input.restore in caller workspace

                    io = obj.input; 
                    todo = '.restore';

                case 'output'
                % test_io.backup

                    io = obj.test_io; 
                    todo = '.backup';
                end
            end

            switch todo
            case '.backup'
                if isfile(io.file)
                    warning('regtest:Checkpoint:do:overwrite', 'Overwriting checkpoint: %s', io.file); 
                end
            case '.restore'
                assert(isfile(io.file), 'regtest:Checkpoint:do:notestfile', 'Failed to find checkpoint: %s', io.file);
            otherwise
                error('You should not be here');
            end
            
            if ~isempty(obj.spyname), spy = obj.spyname;
            else
                % Get a variable name that we can assign in caller
                spy = obj.DEF_SPYNAME;
                if evalin('caller', ['exist(''' spy ''')'])
                    spy = matlab.lang.makeUniqueStrings(spy, evalin('caller','who'));
                end
    
                if strcmp(todo,'.restore')
                    % also make sure our variable name will not be overwritten by restore
                    spy = matlab.lang.makeUniqueStrings(spy, who('-file',io.file));
                end
            end

            try
                assignin('caller', spy, io);

            catch ERR
                if strcmp(ERR.identifier, 'MATLAB:err_static_workspace_violation')
                    error('regtest:Checkpoint:do:err_static_workspace_violation',...
                            ['regtest.Checkpoint.do cannot work on a static workspace, unless you ', ...
                            'define a dummy variable and pass the name to obj.spyname'])
                else
                    rethrow(ERR);
                end
            end

            evalin('caller', [spy todo]);
            evalin('caller', ['clear ' spy]);

            if strcmp(stage,'output'), obj.state = 'idle'; end
        end
    end
end

function mustBeValidVariableNameOrEmpty(var)
    if ~(isempty(var) || isvarname(var))
        throwAsCaller( ...
            MException('MATLAB:validators:mustBeValidVariableName',var));
    end
end