function [scenariosTbl, sweepTbl] = loadBenchmarkData(rootDir)
%LOADBENCHMARKDATA Load validated S1-S4 scenario and (H, D) sweep CSVs.
%   [scenariosTbl, sweepTbl] = wscc9.loadBenchmarkData()
%   [scenariosTbl, sweepTbl] = wscc9.loadBenchmarkData(rootDir)
if nargin < 1 || isempty(rootDir)
    rootDir = fileparts(fileparts(mfilename('fullpath')));
end
scenPath  = fullfile(rootDir, 'results', 'reviewer_fixed_all_scenarios.csv');
sweepPath = fullfile(rootDir, 'results', 'decoupled_H_D_sensitivity.csv');
assert(isfile(scenPath), 'wscc9:MissingFile', 'Missing file: %s', scenPath);
assert(isfile(sweepPath), 'wscc9:MissingFile', 'Missing file: %s', sweepPath);
scenariosTbl = readtable(scenPath, 'TextType', 'string');
sweepTbl     = readtable(sweepPath, 'TextType', 'string');
end