%% WSCC 9-Bus Baseline KPI Extraction & Plotting Script (Updated)
% Assumes f_out and P_out exist in the workspace as Timeseries objects

clearvars -except f_out P_out
clc;

% Check Workspace Variables
if ~exist('f_out', 'var') || ~exist('P_out', 'var')
    error('f_out or P_out missing from Workspace. Run Simulink model first.');
end

% Extract time and data
t = f_out.Time;
f = f_out.Data;
P = P_out.Data;

% Disturbance & Pre-Step Baseline Settings (Evaluated at t = 4.99s)
t_step = 5.0; 
idx_step = find(t >= t_step, 1);
idx_pre_step = find(t < t_step, 1, 'last');

f_base = f(idx_pre_step); % Accurate baseline right before disturbance
P_base = P(idx_pre_step); % Accurate baseline right before disturbance

%% --- KPI CALCULATIONS ---

% 1. Frequency Nadir & Time (Evaluated in post-step window t >= 5.0s)
[f_nadir, idx_nadir_rel] = min(f(idx_step:end));
idx_nadir = idx_step + idx_nadir_rel - 1;
t_nadir = t(idx_nadir);

% 2. Maximum Frequency Deviation (Relative to pre-step baseline)
f_dev = abs(f_base - f_nadir);

% 3. RoCoF (initial 100ms post-step)
idx_100ms = find(t >= t_step + 0.1, 1);
rocof = abs(f(idx_100ms) - f(idx_step)) / (t(idx_100ms) - t(idx_step));

% 4. Frequency Settling Time (+/- 0.02 Hz band of post-fault steady state)
f_post = f(end);
band_f = 0.02;
out_of_band_f = find(abs(f - f_post) > band_f & t >= t_step);
if isempty(out_of_band_f)
    t_settle_f = 0;
else
    t_settle_f = t(out_of_band_f(end)) - t_step;
end

% 5. Active Power Peak & Overshoot (%) relative to pre-step baseline
[P_peak, idx_peak_rel] = max(P(idx_step:end));
idx_peak = idx_step + idx_peak_rel - 1;
P_post = P(end);

delta_P_steady = abs(P_post - P_base);
if delta_P_steady > 1e-4
    P_overshoot_pct = ((P_peak - P_post) / delta_P_steady) * 100;
else
    P_overshoot_pct = 0;
end

% 6. Active Power Settling Time (+/- 2% band of delta P)
band_P = 0.02 * delta_P_steady;
if band_P == 0, band_P = 0.001; end
out_of_band_P = find(abs(P - P_post) > band_P & t >= t_step);
if isempty(out_of_band_P)
    t_settle_P = 0;
else
    t_settle_P = t(out_of_band_P(end)) - t_step;
end

% 7. Damping Ratio (zeta) via Logarithmic Decrement
[pks, locs] = findpeaks(P(idx_step:end), t(idx_step:end));
if length(pks) >= 2 && (pks(1) - P_post) > 0 && (pks(2) - P_post) > 0
    delta_val = log((pks(1) - P_post) / (pks(2) - P_post));
    zeta = delta_val / sqrt(4*pi^2 + delta_val^2);
else
    zeta = NaN; % Monotonic or non-oscillatory swing
end

%% --- PRINT TABLE TO COMMAND WINDOW ---

fprintf('\n======================================================\n');
fprintf('       WSCC 9-BUS BASELINE PERFORMANCE METRICS         \n');
fprintf('======================================================\n');
fprintf('  Pre-Step Base Freq (t=4.99s): %8.4f Hz\n', f_base);
fprintf('  Pre-Step Base Power(t=4.99s): %8.4f p.u.\n', P_base);
fprintf('------------------------------------------------------\n');
fprintf('  1. RoCoF (First 100ms)      : %8.4f Hz/s\n', rocof);
fprintf('  2. Frequency Nadir          : %8.4f Hz (at t = %.2f s)\n', f_nadir, t_nadir);
fprintf('  3. Max Frequency Deviation  : %8.4f Hz\n', f_dev);
fprintf('  4. Frequency Settling Time  : %8.4f s\n', t_settle_f);
fprintf('  5. Active Power Overshoot   : %8.4f %%\n', P_overshoot_pct);
fprintf('  6. Power Settling Time      : %8.4f s\n', t_settle_P);
if isnan(zeta)
    fprintf('  7. Damping Ratio (zeta)     : Monotonic / Overdamped\n');
else
    fprintf('  7. Damping Ratio (zeta)     : %8.4f\n', zeta);
end
fprintf('======================================================\n\n');

%% --- GRAPH GENERATION ---

figure('Name', 'WSCC 9-Bus System Dynamics', 'Color', 'w', 'Position', [100, 100, 900, 600]);

% --- Subplot 1: Frequency Response ---
subplot(2, 1, 1);
plot(t, f, 'b-', 'LineWidth', 1.8); hold on;
xline(t_step, 'r--', 'Step Load Added (+30MW)', 'LineWidth', 1.2, 'LabelVerticalAlignment', 'bottom');
plot(t_nadir, f_nadir, 'ro', 'MarkerSize', 8, 'MarkerFaceColor', 'r');
text(t_nadir + 0.2, f_nadir, sprintf(' Nadir: %.3f Hz', f_nadir), 'Color', 'r', 'FontWeight', 'bold');

% Pre-Step Baseline and Settling Bands
yline(f_base, 'g--', 'Pre-Step Base', 'LineWidth', 1);
yline(f_post + band_f, 'k:', 'LineWidth', 1);
yline(f_post - band_f, 'k:', 'LineWidth', 1);

grid on;
title('System Frequency Response (f_{out})', 'FontSize', 12, 'FontWeight', 'bold');
xlabel('Time (s)');
ylabel('Frequency (Hz)');
xlim([0, t(end)]);

% --- Subplot 2: Generator Active Power Response ---
subplot(2, 1, 2);
plot(t, P, 'm-', 'LineWidth', 1.8); hold on;
xline(t_step, 'r--', 'Step Load Added (+30MW)', 'LineWidth', 1.2, 'LabelVerticalAlignment', 'bottom');
plot(t(idx_peak), P_peak, 'ks', 'MarkerSize', 8, 'MarkerFaceColor', 'm');

% Pre-Step Baseline and Settling Bands
yline(P_base, 'g--', 'Pre-Step Base', 'LineWidth', 1);
yline(P_post + band_P, 'k:', 'LineWidth', 1);
yline(P_post - band_P, 'k:', 'LineWidth', 1);

grid on;
title('Generator 1 Active Power Response (P_{out})', 'FontSize', 12, 'FontWeight', 'bold');
xlabel('Time (s)');
ylabel('Active Power (p.u.)');
xlim([0, t(end)]);

sgtitle('WSCC 9-Bus Step-Load Response Analysis', 'FontSize', 14, 'FontWeight', 'bold');