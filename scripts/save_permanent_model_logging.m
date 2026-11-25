rootDir = 'D:\final year project';
mdlDir  = fullfile(rootDir, 'models');
scrDir  = fullfile(rootDir, 'scripts');
if ~isfolder(scrDir), mkdir(scrDir); end
try Simulink.sdi.setRecordData(true); catch, end
mdls = {'WSCC01', 'finalmodel1', 'finalmodel2', 'finalmodel3'};
for k = 1:numel(mdls)
    m = mdls{k};
    mFile = fullfile(mdlDir, [m '.slx']);
    if ~isfile(mFile), warning('Missing model: %s', mFile); continue; end
    if bdIsLoaded(m), close_system(m, 0); end
    load_system(mFile);
    cs = getActiveConfigSet(m);
    if isa(cs, 'Simulink.ConfigSetRef')
        csCopy = copy(cs);
        csCopy.Name = 'PaperBenchmarkConfig';
        attachConfigSet(m, csCopy, true);
        setActiveConfigSet(m, 'PaperBenchmarkConfig');
    end
    try set_param(m, 'ExtMode', 'off', 'LimitDataPoints', 'off', 'Decimation', '1', 'FastRestart', 'off'); catch, end
    try set_param(m, 'SaveTime', 'on', 'TimeSaveName', 'tout', 'SaveOutput', 'on', 'OutputSaveName', 'yout', 'SaveFormat', 'Dataset'); catch, end
    tw = find_system(m, 'MatchFilter', @Simulink.match.allVariants, 'BlockType', 'ToWorkspace');
    for i = 1:numel(tw)
        try set_param(tw{i}, 'SaveFormat', 'Timeseries', 'MaxDataPoints', 'inf', 'Decimation', '1'); catch, end
    end
    save_system(m, mFile);
    close_system(m, 0);
    fprintf('[SAVED] %s (%d ToWorkspace blocks configured)\n', m, numel(tw));
end
