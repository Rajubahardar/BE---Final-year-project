function demo_all(mode)
%% demo_all.m - Master Entrypoint (Updated with All 7 Reviewer Fixes)
if nargin < 1, mode = 'fast'; end
rootDir = fileparts(mfilename('fullpath'));
cd(rootDir); restoredefaultpath; addpath(fullfile(rootDir, 'scripts'), fullfile(rootDir, 'models')); clc;
if strcmpi(mode, 'resim'), run(fullfile(rootDir, 'scripts', 'fix_and_calibrate_all.m')); return; end
k0 = load(fullfile(rootDir, 'data', 'model0_kpis.mat'), 'kpi0').kpi0;
k1 = load(fullfile(rootDir, 'data', 'model1_kpis.mat'), 'kpi1').kpi1;
k2 = load(fullfile(rootDir, 'data', 'model2_kpis.mat'), 'k2').k2;
k3 = load(fullfile(rootDir, 'data', 'model3_kpis.mat'), 'kpi3').kpi3;
fprintf('=========================================================================================================\n');
fprintf('  MASTER KPI BENCHMARK TABLE (60.000 Hz CALIBRATED | PCC BUS 2 | +30.0 MW STEP AT t = 50.0 s)\n');
fprintf('=========================================================================================================\n');
fprintf('  #  | Key Performance Indicator     | Unit   | Model 0 (IEEE-9) | Model 1 (GFL)  | Model 2 (VSG)  | Model 3 (Sync)\n');
fprintf('---------------------------------------------------------------------------------------------------------\n');
fprintf('  0  | Pre-Step Freq Baseline        | Hz     | %16.4f | %14.4f | %14.4f | %14.4f\n', k0.f_base, k1.f_base, k2.f_base, k3.f_base);
fprintf('  1  | Maximum RoCoF (500 ms PCC)    | Hz/s   | %16.4f | %14.4f | %14.4f | %14.4f\n', k0.rocof, k1.rocof, k2.rocof, k3.rocof);
fprintf('  2  | Frequency Nadir               | Hz     | %16.4f | %14.4f | %14.4f | %14.4f\n', k0.f_nadir, k1.f_nadir, k2.f_nadir, k3.f_nadir);
fprintf('  3  | Max Freq Excursion |df|       | Hz     | %16.4f | %14.4f | %14.4f | %14.4f\n', k0.f_dev, k1.f_dev, k2.f_dev, k3.f_dev);
fprintf('  4  | Frequency Settling Time       | s      | %16.4f | %14.4f | %14.4f | %14.4f\n', k0.t_settle_f, k1.t_settle_f, k2.t_settle_f, k3.t_settle_f);
fprintf('  5  | Active-Power Settling Time    | s      | %16.4f | %14.4f | %14.4f | %14.4f\n', k0.t_settle_P, k1.t_settle_P, k2.t_settle_P, k3.t_settle_P);
fprintf('  6a | Power Overshoot (Step-Norm)   | %%      | %16.4f | %14.4f | %14.4f | %14.4f\n', k0.P_overshoot, k1.P_overshoot, k2.P_overshoot, k3.P_overshoot);
fprintf('  6b | Peak Power Surge (S_rated)    | %%      | %16.4f | %14.4f | %14.4f | %14.4f\n', k0.dP_surge_pu, k1.dP_surge_pu, k2.dP_surge_pu, k3.dP_surge_pu);
fprintf('  7  | Maximum Voltage Deviation     | %%      | %16.4f | %14.4f | %14.4f | %14.4f\n', k0.V_dev_pct, k1.V_dev_pct, k2.V_dev_pct, k3.V_dev_pct);
fprintf('  8  | Damping Ratio (zeta)          | -      | %16.4f | %14.4f | %14.4f | %14.4f\n', k0.damping, k1.damping, k2.damping, k3.damping);
fprintf('  9  | PCC Voltage THD (THDv)        | %%      | %16.4f | %14.4f | %14.4f | %14.4f\n', k0.THD_V, k1.THD_V, k2.THD_V, k3.THD_V);
fprintf(' 10  | PCC Current THD (THDi)        | %%      | %16.4f | %14.4f | %14.4f | %14.4f\n', k0.THD_I, k1.THD_I, k2.THD_I, k3.THD_I);
fprintf('=========================================================================================================\n');
if exist(fullfile(rootDir, 'results', 'reviewer_fixed_all_scenarios.csv'), 'file')
    fprintf('\n--- MULTI-SCENARIO CONTINGENCY BENCHMARK (S1-S4) ---\n');
    disp(readtable(fullfile(rootDir, 'results', 'reviewer_fixed_all_scenarios.csv')));
end
if exist(fullfile(rootDir, 'results', 'decoupled_H_D_sensitivity.csv'), 'file')
    fprintf('\n--- DECOUPLED H-ONLY AND D-ONLY SENSITIVITY SWEEPS ---\n');
    disp(readtable(fullfile(rootDir, 'results', 'decoupled_H_D_sensitivity.csv')));
end
end
