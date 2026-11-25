function demo_all
clc; rootDir = fileparts(mfilename('fullpath'));
fprintf('=== MASTER S1-S4 BENCHMARK TABLE ===\n');
disp(readtable(fullfile(rootDir,'results','reviewer_fixed_all_scenarios.csv')));
fprintf('=== DECOUPLED (H, D) SENSITIVITY SWEEP TABLE ===\n');
disp(readtable(fullfile(rootDir,'results','decoupled_H_D_sensitivity.csv')));
end
