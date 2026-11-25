function startup()
%STARTUP Configure repository paths and isolate Simulink build artifacts.
rootDir = fileparts(mfilename('fullpath'));
addpath(rootDir);
if isfolder(fullfile(rootDir, 'models'))
    addpath(fullfile(rootDir, 'models'));
end
if exist('Simulink.fileGenControl', 'file')
    cacheDir = fullfile(rootDir, '_sim_cache');
    if ~isfolder(cacheDir), mkdir(cacheDir); end
    Simulink.fileGenControl('set', ...
        'CacheFolder', cacheDir, ...
        'CodeGenFolder', cacheDir, ...
        'createDir', true);
end
fprintf('[wscc9] Environment initialized (%s)\n', rootDir);
end