function demo_all(mode)
%% demo_all.m
% Master Entrypoint: Verifies KPIs, computes theoretical errors, and generates README plots.
% Usage:
%   demo_all           -> Loads verified .mat datasets & generates plots (< 5 s)
%   demo_all('resim')  -> Re-runs Simulink models from scratch before generating plots
if nargin < 1, mode = 'fast'; end

rootDir = fileparts(mfilename('fullpath'));
addpath(genpath(rootDir));
clc;

fprintf('==================================================================================\n');
fprintf('  WSCC 9-BUS DYNAMIC STABILITY BENCHMARK: MODEL 0 (SG) vs GFL (1) vs VSG (2) vs (3)\n');
fprintf('==================================================================================\n');
fprintf('Project Root : %s\n', rootDir);
fprintf('Mode         : %s\n\n', upper(mode));

%% 1. OPTIONAL FULL RE-SIMULATION
if strcmpi(mode, 'resim')
    if exist(fullfile(rootDir, 'scripts', 'run_kpi_analysis.m'), 'file')
        fprintf('[1/4] Running Model 0 (WSCC01.slx)...\n');
        run(fullfile(rootDir, 'scripts', 'run_kpi_analysis.m'));
    end
    if exist(fullfile(rootDir, 'scripts', 'run_vsg_kpi.m'), 'file')
        fprintf('[1/4] Running Model 2 (finalmodel2.slx) 110 s EMT sweep...\n');
        run(fullfile(rootDir, 'scripts', 'run_vsg_kpi.m'));
        if exist('vsg_kpis.mat', 'file')
            movefile('vsg_kpis.mat', fullfile(rootDir, 'data', 'vsg_kpis.mat'), 'f');
        end
        if exist('vsg_kpi_summary.csv', 'file')
            movefile('vsg_kpi_summary.csv', fullfile(rootDir, 'data', 'vsg_kpi_summary.csv'), 'f');
        end
    end
else
    fprintf('[1/4] Loading verified simulation datasets (run demo_all(''resim'') to re-simulate)...\n');
end

%% 2. LOAD MODEL 2 (VSG) KPI DATASET
kpiFile = fullfile(rootDir, 'data', 'vsg_kpis.mat');
if ~exist(kpiFile, 'file')
    error('Missing data/vsg_kpis.mat. Run demo_all(''resim'') first.');
end
S = load(kpiFile, 'results');
T_vsg = struct2table(S.results);

fprintf('\n[2/4] EXTRACTED MODEL 2 (VSG) MULTI-CASE KPI TABLE:\n');
disp(T_vsg);

%% 3. THEORETICAL CROSS-VERIFICATION & ERROR AUDIT
fprintf('[3/4] THEORETICAL VERIFICATION (30 MW Bus 5 Step Load at t = 50.0 s):\n');
f0       = 60.0;
dP_MW    = 30.0;
S_vsg    = 11.0;
M_sys    = (dP_MW * f0) / 0.1443;      % 12,474.01 MW*s from Model 1 GFL COI baseline
beta_gov = 450.0 / (0.05 * f0);        % 150.0 MW/Hz system governor droop bias

df_ss_th_vec = zeros(height(T_vsg), 1);

for i = 1:height(T_vsg)
    H        = T_vsg.H_vsg(i);
    D_pu     = T_vsg.D_pu(i);
    rocof_th = (dP_MW * f0) / (M_sys + 2 * H * S_vsg);
    df_ss_th = dP_MW / (beta_gov + (D_pu * S_vsg) / f0);
    err_df   = abs(T_vsg.Delta_f_ss(i) - df_ss_th) / df_ss_th * 100;

    df_ss_th_vec(i) = df_ss_th;

    fprintf('  Case H=%.1fs, D=%2.0fpu | Sim RoCoF=%.4f Hz/s (COI Th=%.4f) | Sim df_ss=%.4f Hz vs Th=%.4f Hz (Err=%.2f%%) | THDi=%.2f%%\n', ...
        H, D_pu, T_vsg.RoCoF_max(i), rocof_th, T_vsg.Delta_f_ss(i), df_ss_th, err_df, T_vsg.THD_I_pct(i));
end

%% 4. EXPORT HIGH-RESOLUTION PNG CHARTS FOR README.md
figDir = fullfile(rootDir, 'results');
if ~exist(figDir, 'dir'), mkdir(figDir); end

% --- Plot 1: GFL (Model 1) vs VSG (Model 2) Headline KPI Comparison ---
f1 = figure('Color', 'w', 'Position', [80, 80, 1150, 380], 'Visible', 'off');
labels = {'GFL (M1)', 'VSG (5s,20)', 'VSG (2s,60)', 'VSG (8s,20)'};

subplot(1, 3, 1);
b1 = bar([0.5019; T_vsg.RoCoF_max], 'FaceColor', 'flat');
b1.CData = [0.82 0.25 0.25; 0.18 0.48 0.75; 0.15 0.65 0.45; 0.25 0.35 0.68];
set(gca, 'XTickLabel', labels); xtickangle(15);
ylabel('RoCoF_{max} (Hz/s)'); title('Peak RoCoF (-78% to -83% vs GFL)'); grid on;

subplot(1, 3, 2);
b2 = bar([59.3648; T_vsg.f_nadir], 'FaceColor', 'flat');
b2.CData = [0.82 0.25 0.25; 0.18 0.48 0.75; 0.15 0.65 0.45; 0.25 0.35 0.68];
ylim([59.1, 60.0]);
set(gca, 'XTickLabel', labels); xtickangle(15);
ylabel('Frequency Nadir (Hz)'); title('Post-Disturbance Frequency Nadir'); grid on;

subplot(1, 3, 3);
b3 = bar([22.4537; T_vsg.t_settle], 'FaceColor', 'flat');
b3.CData = [0.82 0.25 0.25; 0.18 0.48 0.75; 0.15 0.65 0.45; 0.25 0.35 0.68];
set(gca, 'XTickLabel', labels); xtickangle(15);
ylabel('2% Settling Time (s)'); title('Frequency Settling Time'); grid on;

saveas(f1, fullfile(figDir, 'gfl_vs_vsg_comparison.png'));
close(f1);

% --- Plot 2: VSG Sensitivity, Theory vs Sim & IEEE 519 Harmonics ---
f2 = figure('Color', 'w', 'Position', [100, 100, 1150, 420], 'Visible', 'off');
vsgLabels = {'H=5s, D=20', 'H=2s, D=60', 'H=8s, D=20'};

subplot(1, 3, 1);
bar([T_vsg.Delta_f_ss, df_ss_th_vec]);
set(gca, 'XTickLabel', vsgLabels); xtickangle(15);
ylabel('\Deltaf_{ss} (Hz)'); title('Steady-State Droop: Sim vs Theory');
legend('Simulated', 'Theoretical', 'Location', 'best'); grid on;

subplot(1, 3, 2);
bar([T_vsg.V_pcc_min, T_vsg.V_pcc_max]);
set(gca, 'XTickLabel', vsgLabels); xtickangle(15);
ylabel('PCC Voltage (pu)'); title('PCC Voltage Envelope (V_{min} / V_{max})');
legend('V_{PCC,min}', 'V_{PCC,max}', 'Location', 'best'); grid on;

subplot(1, 3, 3);
bar([T_vsg.THD_V_pct, T_vsg.THD_I_pct]); hold on;
yline(5.0, 'r--', 'IEEE 519 Limit (5%)', 'LineWidth', 1.2);
set(gca, 'XTickLabel', vsgLabels); xtickangle(15);
ylabel('THD (%)'); title('IEEE 519 Power Quality (20 kHz EMT)');
legend('THD_V (%)', 'THD_I (%)', 'Location', 'best'); grid on;

saveas(f2, fullfile(figDir, 'vsg_theory_and_harmonics.png'));
close(f2);

fprintf('\n[4/4] Generated PNG charts inside: %s\n', figDir);
fprintf('==================================================================================\n');
end