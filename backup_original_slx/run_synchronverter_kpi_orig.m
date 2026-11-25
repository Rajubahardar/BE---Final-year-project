%% =========================================================================
%  WSCC 9-BUS SYNCHRONVERTER KPI EXTRACTION PIPELINE (finalmodel3.slx)
%  Matches finalmodel1's 8.28 MW Bus 2 pre-step dispatch & +30 MW Bus 5 step
%  at t = 50 s over 110 s, and computes all 7 dynamic KPIs + PCC THD.
%  =========================================================================
clc; clear; close all;
cd('C:\Matlab_Workspace');

if exist('finalmodel3.mat', 'file')
    load('finalmodel3.mat');
end

mdl = 'finalmodel3';
cfg = struct();
cfg.Ts          = 50e-6;     % Discrete sample time (20 kHz)
cfg.t_stop      = 110.0;     % Simulation stop time (s)
cfg.t_step      = 50.0;      % Bus 5 +30 MW breaker switching time (s)
cfg.pre_start   = 35.0;      % Settled pre-disturbance window start (s)
cfg.pre_guard   = 0.1;       % Guard before t_step (s)
cfg.final_win   = 5.0;       % Steady-state final window (s)
cfg.rocof_win   = 0.5;       % 100 ms RoCoF regression window (s)
cfg.fc          = 15.0;      % Zero-phase low-pass cutoff (Hz)
cfg.band_f      = 0.02;      % Frequency settling band (+/- Hz)
cfg.band_P_frac = 0.02;      % Power settling band (+/- 2% of |dP|)
cfg.dwell_s     = 1.0;       % Minimum dwell time inside band (s)
cfg.f_hp        = 0.8;       % High-pass cutoff for oscillatory mode extraction (Hz)
cfg.damp_win    = 10.0;      % Post-step window for damping fit (s)
cfg.f0          = 60.0;      % Nominal grid frequency (Hz)
cfg.S_G3_MVA    = 128.0;     % Generator 3 base rating (MVA)

%% 1. RECOVER WSCC 9-BUS PSS PARAMETERS & EXACT BUS 2 PRE-STEP DISPATCH
P_bus2_MW = 8.28; % Verified Bus 2 PV dispatch from finalmodel1 (Nser=11, Npar=3500)
if exist('finalmodel1.slx', 'file')
    load_system('finalmodel1');

    % Read exact Bus 2 active power from PV Array1 mask variables
    pv = find_system('finalmodel1', 'LookUnderMasks', 'all', 'Name', 'PV Array1');
    if ~isempty(pv)
        try
            nser = str2double(get_param(pv{1}, 'Nser'));
            npar = str2double(get_param(pv{1}, 'Npar'));
            mws  = get_param(pv{1}, 'MaskWSVariables');
            idx_pm = find(strcmp({mws.Name}, 'Pm') | strcmp({mws.Name}, 'Pmax'), 1);
            if ~isempty(idx_pm) && isfinite(nser * npar * mws(idx_pm).Value)
                P_bus2_MW = (nser * npar * mws(idx_pm).Value) / 1e6;
            end
        catch
        end
    end

    % Restore WSCC 9-bus parameters (k1..k13) if missing from workspace
    if ~exist('k1', 'var') || ~exist('k8', 'var')
        for cb = {'PreLoadFcn', 'InitFcn', 'PostLoadFcn'}
            cmd = get_param('finalmodel1', cb{1});
            if ~isempty(cmd), try eval(cmd); catch, end; end
        end
        mws1 = get_param('finalmodel1', 'ModelWorkspace');
        if ~isempty(mws1)
            wvars = mws1.whos;
            for i = 1:numel(wvars)
                if ~exist(wvars(i).name, 'var')
                    eval([wvars(i).name ' = mws1.getVariable(''' wvars(i).name ''');']);
                end
            end
        end
    end
    close_system('finalmodel1', 0);
end

if ~exist('k1', 'var') || ~exist('k8', 'var')
    mats = dir('*.mat');
    for i = 1:numel(mats)
        if ~strcmp(mats(i).name, 'finalmodel3.mat') && ~startsWith(mats(i).name, 'wscc9_raw_')
            info = whos('-file', mats(i).name);
            if any(strcmp({info.name}, 'k1')) || any(strcmp({info.name}, 'k8'))
                load(mats(i).name);
                break;
            end
        end
    end
end
fprintf('Bus 2 Pre-Step Active Power Setpoint: %.2f MW\n', P_bus2_MW);

%% 2. SCALE SYNCHRONVERTER & LCL FILTER TO BUS 2 RATING
Ts         = cfg.Ts;
SampleTime = Ts;
fg         = cfg.f0;
Wn         = 2 * pi * fg;
Vlgrms     = 400;                      % Transformer LV winding (400 V LL rms)
Vnpeak     = Vlgrms * sqrt(2/3);       % Nominal peak phase voltage (326.5986 V)
Vdclink    = 800;                      % DC-link voltage (V)

Srated     = ceil((P_bus2_MW / 0.80)) * 1e6; % ~11 MVA base for 8.28 MW dispatch
Pset       = P_bus2_MW * 1e6;          % Active power setpoint (W)
Qset       = 0;                        % Reactive power setpoint (VAr)

% Physical Virtual Synchronous Machine (VSM) parameters
H_vsm      = 5.0;                      % Virtual inertia constant (s)
R_droop    = 0.05;                     % 5% active & reactive droop
Dp         = Srated / (R_droop * Wn^2);
tf         = 2 * H_vsm * R_droop;      % J / Dp (s)
Dq         = Srated / (R_droop * Vnpeak);
tv         = 0.05;                     % Voltage loop time constant (s)

% Virtual stator impedance (Xv = 0.15 pu, Rv = 0.02 pu on Srated)
Zbase      = (Vlgrms^2) / Srated;
L          = (0.15 * Zbase) / Wn;
R          = 0.02 * Zbase;
Kp         = 1;
Ki         = 9;

% Discrete 20 Hz low-pass filter coefficients for Controller (Ts = 50 us)
wc_lp      = 2 * pi * 20;
a0         = 2 + wc_lp * Ts;
num_d      = [(wc_lp * Ts)/a0, (wc_lp * Ts)/a0];
den_d      = [1, (wc_lp * Ts - 2)/a0];

% Scale 400 V LCL filter branches to Zbase (X_L1 = 0.05 pu, X_L2 = 0.03 pu, Q_C = 0.05 pu)
Ls         = (0.05 * Zbase) / Wn;
Rs         = 0.002 * Zbase;
Lg         = (0.03 * Zbase) / Wn;
Rg         = 0.002 * Zbase;
Cf         = 0.05 / (Wn * Zbase);
w_res      = sqrt((Ls + Lg) / (Ls * Lg * Cf));
Rd         = 1 / (3 * w_res * Cf);
fs         = 15000;
Ws         = 2 * pi * fs;

save('finalmodel3.mat');

%% 3. CONFIGURE FINALMODEL3, BREAK ALGEBRAIC LOOP & WIRE PCC THD LOGGERS
if bdIsLoaded(mdl)
    close_system(mdl, 0); % Discard any partial in-memory edits from aborted run
end
load_system(mdl);

% Update LCL filter parameters to match Zbase
if getSimulinkBlockHandle([mdl '/Three-Phase Series RLC Branch1']) ~= -1
    set_param([mdl '/Three-Phase Series RLC Branch1'], 'Resistance', num2str(Rs), 'Inductance', num2str(Ls));
end
if getSimulinkBlockHandle([mdl '/Three-Phase Series RLC Branch2']) ~= -1
    set_param([mdl '/Three-Phase Series RLC Branch2'], 'Resistance', num2str(Rg), 'Inductance', num2str(Lg));
end
if getSimulinkBlockHandle([mdl '/Three-Phase Series RLC Branch3']) ~= -1
    set_param([mdl '/Three-Phase Series RLC Branch3'], 'Resistance', num2str(Rd), 'Capacitance', num2str(Cf));
end

% Break Controller/Switch algebraic loop with a 1-step Ts delay (5x faster simulation)
sw = [mdl '/Controller/Switch'];
ud = [mdl '/Controller/LoopBreaker_Delay'];
if getSimulinkBlockHandle(sw) ~= -1 && getSimulinkBlockHandle(ud) == -1
    ph  = get_param(sw, 'PortHandles');
    ln  = get_param(ph.Outport(1), 'Line');
    dst = get_param(ln, 'DstPortHandle');
    pos = get_param(sw, 'Position');
    delete_line(ln);
    add_block('simulink/Discrete/Unit Delay', ud, ...
        'SampleTime', 'Ts', 'InitialCondition', '0', ...
        'Position', [pos(3)+20, pos(2)+15, pos(3)+50, pos(4)-15]);
    ud_ph = get_param(ud, 'PortHandles');
    add_line([mdl '/Controller'], ph.Outport(1), ud_ph.Inport(1), 'autorouting', 'on');
    for k = 1:length(dst)
        add_line([mdl '/Controller'], ud_ph.Outport(1), dst(k), 'autorouting', 'on');
    end
end

% Enforce 110 s duration, Accelerator mode, ode4 solver, and t = 50.0 s Bus 5 load step
set_param(mdl, 'StopTime', num2str(cfg.t_stop), 'SimulationMode', 'accelerator', ...
    'Solver', 'ode4', 'FixedStep', 'SampleTime');
brk = [mdl '/Three-Phase Breaker'];
if getSimulinkBlockHandle(brk) ~= -1
    set_param(brk, 'SwitchTimes', sprintf('[%g]', cfg.t_step));
end

% Ensure unlimited points on all ToWorkspace blocks
tw_all = find_system(mdl, 'LookUnderMasks', 'all', 'BlockType', 'ToWorkspace');
for k = 1:numel(tw_all)
    try set_param(tw_all{k}, 'MaxDataPoints', 'inf'); catch, end
end

% Wire PCC V-I measurement & Vpcc_log / Ipcc_log right after LCL Branch2
br2 = [mdl '/Three-Phase Series RLC Branch2'];
pcc_vi = [mdl '/PCC_VI_Meas'];
if getSimulinkBlockHandle(br2) ~= -1 && getSimulinkBlockHandle(pcc_vi) == -1
    pc2 = get_param(br2, 'PortConnectivity');
    ii  = find(strcmp({pc2.Type}, 'RConn1'), 1);
    dst_blk = pc2(ii).DstBlock;
    dst_blk = dst_blk(dst_blk > 0);
    if ~isempty(dst_blk)
        dst_ph = get_param(dst_blk(1), 'PortHandles');
        br2_ph = get_param(br2, 'PortHandles');
        pos2   = get_param(br2, 'Position');
        for p = 1:min(3, numel(br2_ph.RConn))
            ln = get_param(br2_ph.RConn(p), 'Line');
            if ln ~= -1, delete_line(ln); end
        end
        add_block('powerlib/Measurements/Three-Phase V-I Measurement', pcc_vi, ...
            'VoltageMeasurement', 'phase-to-ground', 'CurrentMeasurement', 'yes', ...
            'Position', [pos2(3)+35, pos2(2)-10, pos2(3)+85, pos2(4)+10]);
        vi_ph = get_param(pcc_vi, 'PortHandles');
        for p = 1:3
            add_line(mdl, br2_ph.RConn(p), vi_ph.LConn(p), 'autorouting', 'on');
            add_line(mdl, vi_ph.RConn(p), dst_ph.LConn(p), 'autorouting', 'on');
        end
        add_block('simulink/Sinks/To Workspace', [mdl '/Vpcc_ToWS'], ...
            'VariableName', 'Vpcc_log', 'SaveFormat', 'Timeseries', ...
            'SampleTime', 'SampleTime', 'MaxDataPoints', 'inf', ...
            'Position', [pos2(3)+105, pos2(2)-45, pos2(3)+175, pos2(2)-25]);
        add_block('simulink/Sinks/To Workspace', [mdl '/Ipcc_ToWS'], ...
            'VariableName', 'Ipcc_log', 'SaveFormat', 'Timeseries', ...
            'SampleTime', 'SampleTime', 'MaxDataPoints', 'inf', ...
            'Position', [pos2(3)+105, pos2(2)-15, pos2(3)+175, pos2(2)+5]);
        vph = get_param([mdl '/Vpcc_ToWS'], 'PortHandles');
        iph = get_param([mdl '/Ipcc_ToWS'], 'PortHandles');
        add_line(mdl, vi_ph.Outport(1), vph.Inport(1), 'autorouting', 'on');
        add_line(mdl, vi_ph.Outport(2), iph.Inport(1), 'autorouting', 'on');
    end
end

%% 4. RUN 110.0-SECOND SIMULATION
fprintf('\n=== RUNNING %.0f-s SIMULATION OF FINALMODEL3 (Srated = %.0f MVA, Pset = %.2f MW) ===\n', ...
    cfg.t_stop, Srated/1e6, Pset/1e6);
tic;
simOut = sim(mdl);
fprintf('Simulation completed in %.2f s.\n', toc);

%% 5. EXTRACT WAVEFORMS & APPLY BENCHMARK FILTERING / RESAMPLING
P_ts  = simOut.get('P_out');
f_ts  = simOut.get('f_out');
t     = double(f_ts.Time(:));
f_raw = double(squeeze(f_ts.Data(:)));
tP    = double(P_ts.Time(:));
P_raw = double(squeeze(P_ts.Data(:)));

fs_f = 1 / median(diff(t));
fs_P = 1 / median(diff(tP));
[bF, aF] = butter(2, cfg.fc / (fs_f / 2), 'low');
[bP, aP] = butter(2, cfg.fc / (fs_P / 2), 'low');
f_filt = filtfilt(bF, aF, f_raw);
P_filt = interp1(tP, filtfilt(bP, aP, P_raw), t, 'linear', 'extrap');

% Resample post-disturbance active power at 100 Hz (Tc = 0.01 s) + 2 s moving average
Tc      = 0.01;
tg      = (cfg.t_step : Tc : cfg.t_stop)';
pg_100  = interp1(t, P_filt, tg, 'linear');
w_ma    = round(2.0 / Tc); % 200 samples = 2.0 s window
ps_ma   = movmean(pg_100, w_ma, 'Endpoints', 'shrink');

%% 6. COMPUTE ALL 7 DYNAMIC KPIs FROM SIMULATED WAVEFORMS
idx_pre  = t >= cfg.pre_start & t < cfg.t_step - cfg.pre_guard;
idx_post = t >= cfg.t_step;
idx_fin  = t >= (cfg.t_stop - cfg.final_win);

f_base = mean(f_filt(idx_pre));
P_base = mean(P_filt(idx_pre));
f_post = mean(f_filt(idx_fin));
P_post = mean(P_filt(idx_fin));
dP     = P_post - P_base;

% KPI 1: Maximum RoCoF (Hz/s) over first 100 ms post-step
idx_rocof = t >= cfg.t_step & t <= cfg.t_step + cfg.rocof_win;
p_rocof   = polyfit(t(idx_rocof) - cfg.t_step, f_filt(idx_rocof), 1);
kpi_rocof = abs(p_rocof(1));

% KPI 2: Frequency Nadir (Hz)
[kpi_fnadir, idx_nad] = min(f_filt(idx_post));
t_post_vec = t(idx_post);
t_nadir    = t_post_vec(idx_nad);

% KPI 3: Frequency Settling Time (s, +/- 0.02 Hz band with 1.0 s dwell)
kpi_tset_f = calc_settling_time(t, f_filt, f_post, cfg.band_f, cfg.t_step, cfg.dwell_s);

% KPI 4: Active-Power Settling Time (s, 2 s smoothed, +/- 2% of |dP| band)
P_ma_base  = mean(P_filt(idx_pre));
P_ma_fin   = mean(ps_ma(tg >= cfg.t_stop - cfg.final_win));
band_P     = cfg.band_P_frac * abs(P_ma_fin - P_ma_base);
kpi_tset_P_smooth = calc_settling_time(tg, ps_ma, P_ma_fin, band_P, cfg.t_step, cfg.dwell_s);
kpi_tset_P_raw    = calc_settling_time(t, P_filt, P_post, cfg.band_P_frac * abs(dP), cfg.t_step, cfg.dwell_s);

% KPI 5: Active-Power Overshoot (% - raw & 2 s smoothed)
Pe_raw = P_filt(idx_post);
kpi_os_raw    = 100 * max(0, max(sign(dP) * (Pe_raw - P_post))) / max(abs(dP), 1e-6);
kpi_os_smooth = 100 * max(0, max(sign(P_ma_fin - P_ma_base) * (ps_ma - P_ma_fin))) / max(abs(P_ma_fin - P_ma_base), 1e-6);

% KPI 6: Maximum Voltage Deviation (%) across Vt (Array or Timeseries)
kpi_vdev = NaN;
try
    Vp_raw   = simOut.get('Vpcc_log');
    tv       = double(Vp_raw.Time(:));
    Vv       = double(squeeze(Vp_raw.Data));
    Fs_v     = 1 / median(diff(tv));
    cyc_v    = max(1, round(Fs_v / cfg.f0));
    V_rms    = sqrt(movmean(Vv(:, 1).^2, cyc_v));
    V_pre    = mean(V_rms(tv >= cfg.pre_start & tv < cfg.t_step - cfg.pre_guard));
    V_pst    = V_rms(tv >= cfg.t_step);
    kpi_vdev = max(abs(V_pst - V_pre)) / max(V_pre, 1e-6) * 100;
catch
end

% KPI 7: Damping Ratio (zeta) from post-disturbance power oscillation
[bH, aH] = butter(2, cfg.f_hp / (fs_f / 2), 'high');
P_osc    = filtfilt(bH, aH, P_filt);
w_damp   = t >= cfg.t_step + 0.5 & t <= cfg.t_step + cfg.damp_win;
[pks, locs] = findpeaks(P_osc(w_damp), t(w_damp), 'MinPeakProminence', 0.05*max(abs(P_osc(w_damp))), 'MinPeakDistance', 0.3);
keep = pks > 0; pks = pks(keep); locs = locs(keep);
kpi_zeta = NaN;
if numel(pks) >= 2
    n_fit = min(numel(pks), 6);
    c_dec = polyfit(locs(1:n_fit), log(pks(1:n_fit)), 1);
    sigma = -c_dec(1);
    wd    = 2 * pi / mean(diff(locs(1:n_fit)));
    if sigma > 0
        kpi_zeta = sigma / sqrt(sigma^2 + wd^2);
    end
end

%% 7. COMPUTE KPI 8 & 9: PCC VOLTAGE THD (%) & PCC CURRENT THD (%)
kpi_vthd = NaN; kpi_ithd = NaN;
try
    Vp_ts = simOut.get('Vpcc_log');
    Ip_ts = simOut.get('Ipcc_log');
    kpi_vthd = calc_3ph_thd(Vp_ts, cfg.f0, cfg.t_stop - 1.0, cfg.t_stop);
    kpi_ithd = calc_3ph_thd(Ip_ts, cfg.f0, cfg.t_stop - 1.0, cfg.t_stop);
catch
end

save('wscc9_raw_synchronverter_t50.mat', 't', 'f_raw', 'f_filt', 'P_raw', 'P_filt', ...
    'tg', 'ps_ma', 'f_base', 'P_base', 'kpi_rocof', 'kpi_fnadir', 'kpi_tset_f', ...
    'kpi_tset_P_smooth', 'kpi_tset_P_raw', 'kpi_os_raw', 'kpi_os_smooth', ...
    'kpi_vdev', 'kpi_zeta', 'kpi_vthd', 'kpi_ithd', '-v7');

%% 8. PRINT MASTER COMPARATIVE TABLE (GFL BASELINE VS. SYNCHRONVERTER)
fprintf('\n=========================================================================================\n');
fprintf('         WSCC 9-BUS MASTER COMPARATIVE RESULTS: GFL BASELINE vs. SYNCHRONVERTER\n');
fprintf('         (Pre-Step Freq = %.4f Hz | Pre-Step G3 Power = %.4f pu)\n', f_base, P_base);
fprintf('=========================================================================================\n');
fprintf('%-30s | %-8s | %-18s | %-22s\n', 'Key Performance Indicator', 'Unit', 'GFL (model1.pdf)', 'Synchronverter (Sim)');
fprintf('-----------------------------------------------------------------------------------------\n');
fprintf('%-30s | %-8s | %-18s | %.4f\n', '1. Maximum RoCoF', 'Hz/s', '0.5019', kpi_rocof);
fprintf('%-30s | %-8s | %-18s | %.4f (at %.2f s)\n', '2. Frequency nadir', 'Hz', '59.3648', kpi_fnadir, t_nadir);
fprintf('%-30s | %-8s | %-18s | %.4f\n', '3. Frequency settling time', 's', '22.4537', kpi_tset_f);
fprintf('%-30s | %-8s | %-18s | %.4f (smooth) / %.4f (raw)\n', '4. Active-power settling time', 's', '42.5600 (smooth)', kpi_tset_P_smooth, kpi_tset_P_raw);
fprintf('%-30s | %-8s | %-18s | %.4f (raw) / %.4f (smooth)\n', '5. Active-power overshoot', '%', '18.1755 / 13.5902', kpi_os_raw, kpi_os_smooth);
fprintf('%-30s | %-8s | %-18s | %.4f\n', '6. Maximum voltage deviation', '%', '0.5417', kpi_vdev);
fprintf('%-30s | %-8s | %-18s | %.4f\n', '7. Damping ratio', '-', '0.0298', kpi_zeta);
fprintf('%-30s | %-8s | %-18s | %.4f\n', '8. PCC voltage THD', '%', 'N/A (Phasor)', kpi_vthd);
fprintf('%-30s | %-8s | %-18s | %.4f\n', '9. PCC current THD', '%', 'N/A (Phasor)', kpi_ithd);
fprintf('=========================================================================================\n\n');

%% 9. PLOT SYNCHRONVERTER DYNAMIC RESPONSE
fig = figure('Name', 'WSCC 9-Bus Synchronverter Response', 'Color', 'w', 'Position', [100 80 1050 680]);
tiledlayout(2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

nexttile;
plot(t, f_filt, 'b-', 'LineWidth', 1.5); hold on;
xline(cfg.t_step, 'r--', 'Bus 5 +30 MW Step', 'LineWidth', 1.2);
plot(t_nadir, kpi_fnadir, 'ro', 'MarkerFaceColor', 'r');
yline(f_post + cfg.band_f, 'k:'); yline(f_post - cfg.band_f, 'k:');
grid on; xlim([30 cfg.t_stop]);
ylabel('Frequency (Hz)'); title(sprintf('Synchronverter System Frequency Response (Nadir = %.4f Hz, RoCoF = %.4f Hz/s)', kpi_fnadir, kpi_rocof));

nexttile;
plot(t, P_filt, 'Color', [0.6 0.6 0.8], 'DisplayName', 'Filtered (15 Hz)'); hold on;
plot(tg, ps_ma, 'b-', 'LineWidth', 1.6, 'DisplayName', '2 s Moving Average');
xline(cfg.t_step, 'r--', 'Bus 5 +30 MW Step', 'LineWidth', 1.2, 'HandleVisibility', 'off');
yline(P_ma_fin + band_P, 'k:', 'HandleVisibility', 'off');
yline(P_ma_fin - band_P, 'k:', 'HandleVisibility', 'off');
grid on; xlim([30 cfg.t_stop]);
xlabel('Time (s)'); ylabel('G3 Active Power (pu)');
title(sprintf('Active Power Response (Settling = %.2f s, Smoothed Overshoot = %.2f%%)', kpi_tset_P_smooth, kpi_os_smooth));
legend('Location', 'best');
exportgraphics(fig, 'synchronverter_kpi_response.png', 'Resolution', 200);

%% LOCAL HELPER FUNCTIONS
function tset = calc_settling_time(t, x, xf, band, ts, dwell)
    idx = t >= ts;
    tt = t(idx); xx = x(idx);
    out = ~isfinite(xx) | abs(xx - xf) > band;
    k = find(out, 1, 'last');
    if isempty(k)
        tset = 0;
    elseif k == numel(tt) || (tt(end) - tt(k+1)) < dwell
        tset = NaN;
    else
        tset = tt(k+1) - ts;
    end
end

function thd_pct = calc_3ph_thd(ts_obj, f0, t1, t2)
    t_sig = double(ts_obj.Time(:));
    y_sig = double(squeeze(ts_obj.Data));
    if size(y_sig, 1) ~= numel(t_sig), y_sig = y_sig'; end
    idx   = t_sig >= t1 & t_sig <= t2;
    t_win = t_sig(idx);
    y_win = y_sig(idx, :);
    fs_s  = 1 / median(diff(t_win));
    n_cyc = floor((t_win(end) - t_win(1)) * f0);
    N     = round(n_cyc * fs_s / f0);
    y_win = y_win(end-N+1:end, :);
    thds  = zeros(1, size(y_win, 2));
    for ph = 1:size(y_win, 2)
        Y = abs(fft(y_win(:, ph))) / N;
        Y = Y(1:floor(N/2)+1);
        k1 = round(f0 * N / fs_s) + 1;
        V1 = Y(k1);
        harm_sq = 0;
        for h = 2:50
            kh = round(h * f0 * N / fs_s) + 1;
            if kh <= numel(Y)
                harm_sq = harm_sq + Y(kh)^2;
            end
        end
        thds(ph) = 100 * sqrt(harm_sq) / max(V1, 1e-9);
    end
    thd_pct = mean(thds);
end

% Save unified kpi3 struct for demo_all.m
kpi3 = struct('label', 'Model 3 (Synchronverter)', 'f_base', f_base, 'rocof', kpi_rocof, 'f_nadir', kpi_fnadir, 'f_dev', abs(f_base - kpi_fnadir), 't_settle_f', kpi_tset_f, 't_settle_P', kpi_tset_P_smooth, 'P_overshoot', kpi_os_smooth, 'V_dev_pct', kpi_vdev, 'damping', kpi_zeta, 'THD_V', kpi_vthd, 'THD_I', kpi_ithd);
save(fullfile(fileparts(fileparts(mfilename('fullpath'))), 'data', 'model3_kpis.mat'), 'kpi3');
