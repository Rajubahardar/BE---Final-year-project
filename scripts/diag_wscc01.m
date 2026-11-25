load_system('D:\final year project\models\WSCC01.slx');
fprintf('StopTime: %s | SimMode: %s | SolverType: %s | Solver: %s\n', get_param('WSCC01', 'StopTime'), get_param('WSCC01', 'SimulationMode'), get_param('WSCC01', 'SolverType'), get_param('WSCC01', 'Solver'));
tw = find_system('WSCC01', 'MatchFilter', @Simulink.match.allVariants, 'BlockType', 'ToWorkspace');
for i = 1:numel(tw)
    fprintf('  %-40s | Var: %-8s | ST: %-8s | SaveFmt: %s\n', tw{i}, get_param(tw{i}, 'VariableName'), get_param(tw{i}, 'SampleTime'), get_param(tw{i}, 'SaveFormat'));
end
out = sim('WSCC01', 'ReturnWorkspaceOutputs', 'on');
disp(out.SimulationMetadata.ExecutionInfo);
vars = who(out);
for i = 1:numel(vars)
    v = out.get(vars{i});
    fprintf('  out.%-8s -> class: %-12s | size: %s\n', vars{i}, class(v), mat2str(size(v)));
end
close_system('WSCC01', 0);
