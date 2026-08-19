function plan = buildfile
import matlab.buildtool.tasks.*

plan = buildplan(localfunctions);

if version('-release') < "2026b"
    PkgBuild.startup();
end

plan("clean") = CleanTask;
plan("check") = CodeIssuesTask;
plan("test") = TestTask('tests');
plan("release").Dependencies = ["check" "test"];

plan.DefaultTasks = ["check" "test"];
end

function releaseTask(~)
% Package Toolbox using matlab-toml

    disp('Running release task')
    PkgBuild.fromTOML();
end
