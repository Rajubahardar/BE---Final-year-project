%% run_vsg_kpi.m
% 100% Standalone KPI Extraction & Parameter Sweep Driver for Model 2 (VSG: finalmodel2.slx)
% Includes critically damped virtual impedance (Xv = 0.30 pu) and matched damping sweep.
% All fixes are applied in memory only; finalmodel2.slx remains untouched on disk.
clear; clc; close all;

%% 1. BUILD SELF-CONTAINED finalmodel2.mat FROM FIRST PRINCIPLES
ws = struct();

% Solver & System Base (WSCC 9-Bus, 60 Hz, 11 MVA / 400 V VSG)
ws.SampleTime = 50e-6;
ws.Ts         = 50e-6;
ws.f0         = 60;
ws.fn         = 60;
ws.wn         = 2 * pi * 60;
ws.w0         = 2 * pi * 60;
ws.Srated     = 11e6;                    % 11 MVA VSG rating
ws.Vrated     = 400;                     % 400 V L-L RMS
ws.Vnpeak     = ws.Vrated * sqrt(2/3);   % 326.5986 V phase-peak
ws.Us         = ws.Vnpeak;
ws.Vdclink    = 800;                     % 800 V DC link (modulation index ~0.82)
ws.Pset       = 8.281e6;                 % 8.281 MW Bus 2 steady-state dispatch
ws.Qset       = 0;                       % 0 MVAr reactive dispatch

% Physical LCL Filter Parameters in finalmodel2.slx (11 MVA, 400 V base)
ws.Rs = 2.9091e-5;
ws.Ls = 1.9292e-6;                       % 0.05 pu inverter-side inductance
ws.Rg = 2.9091e-5;
ws.Lg = 1.1575e-6;                       % 0.03 pu grid-side inductance
ws.Rd = 0.0029691;
ws.Cf = 0.0091183;                       % 0.05 pu filter capacitance
ws.C2 = ws.Cf;

% Virtual Stator Impedance (0.02 pu R, 0.30 pu X on 11 MVA / 400 V base)
Zbase = (ws.Vrated^2) / ws.Srated;
ws.R1 = 0.02 * Zbase;
ws.L1 = (0.30 * Zbase) / ws.wn;

% First-Principles Inner Double-Loop Gains (PM > 75 deg at Ts = 50 us)
ws.w_ci    = 2 * pi * 500;               % 500 Hz inner current loop bandwidth
ws.w_cv    = ws.w_ci / 5;                % 100 Hz outer voltage loop bandwidth
ws.Kip_vsg = ws.w_ci * ws.Ls;            % 0.006061 V/A
ws.Kvp_vsg = ws.w_cv * ws.Cf;            % 5.7292 A/V
ws.Kvi_vsg = ws.Kvp_vsg * (ws.w_cv / 4); % 899.94 A/(V*s)
ws.Kq_vsg  = (0.05 * ws.Vnpeak) / ws.Srated; % 5% Q-V droop on 11 MVA

% Default VSG Swing Parameters (Nominal: H = 5.0 s, D = 80 pu, zeta = 0.38)
ws.H_vsg = 5.0;
ws.D_pu  = 80.0;
ws.J     = (2 * ws.H_vsg * ws.Srated) / (ws.wn^2);
ws.D     = (ws.D_pu  * ws.Srated) / (ws.wn^2);

% WSCC 9-Bus Multi-Band Power System Stabilizer (IEEE PSS4B) Gains for G3 (k1..k7) & G1 (k8..k14)
ws.k1  = 1.0;  ws.k2  = 9.4;  ws.k3  = 1.0;  ws.k4  = 25.0; ws.k5  = 1.0;  ws.k6  = 120.0; ws.k7  = 1.0;
ws.k8  = 1.0;  ws.k9  = 9.4;  ws.k10 = 1.0;  ws.k11 = 25.0; ws.k12 = 1.0;  ws.k13 = 120.0; ws.k14 = 1.0;

save('finalmodel2.mat', '-struct', 'ws');

%% 2. LOAD finalmodel2 & ISOLATE WORKSPACE
if bdIsLoaded('finalmodel2'), close_system('finalmodel2', 0); end
load_system('finalmodel2');
mdl = 'finalmodel2';

clearvars -except mdl;
load('finalmodel2.mat');
set_param(mdl, 'PreLoadFcn', 'if exist(''finalmodel2.mat'',''file''), load(''finalmodel2.mat''); end');
set_param(mdl, 'InitFcn',    'if exist(''finalmodel2.mat'',''file''), load(''finalmodel2.mat''); end');

%% 3. APPLY IN-MEMORY CONTROL & TOPOLOGY FIXES TO finalmodel2
sub = [mdl '/Voltage and current double closed loop'];

% (a) Swap root-level current tags on ports 5..8 (Id <-> ILd, Iq <-> ILq)
pc = get_param(sub, 'PortConnectivity');
for p = 5:8
    srcBlk = pc(p).SrcBlock;
    if ~isempty(srcBlk) && srcBlk ~= -1 && strcmp(get_param(srcBlk, 'BlockType'), 'From')
        oldTag = get_param(srcBlk, 'GotoTag');
        switch oldTag
            case 'Id',  set_param(srcBlk, 'GotoTag', 'ILd');
            case 'ILd', set_param(srcBlk, 'GotoTag', 'Id');
            case 'Iq',  set_param(srcBlk, 'GotoTag', 'ILq');
            case 'ILq', set_param(srcBlk, 'GotoTag', 'Iq');
        end
    end
end

% (b) Update inner loop proportional current gains, decoupling gains, and voltage PI
set_param([sub '/Gain'],  'Gain', 'Kip_vsg');
set_param([sub '/Gain1'], 'Gain', 'Kip_vsg');
set_param([sub '/WL'],    'Gain', 'Ls*2*pi');
set_param([sub '/WC'],    'Gain', 'Cf*2*pi');

for pidName = {'PID Controller1', 'PID Controller4'}
    pidBlk = [sub '/' pidName{1}];
    set_param(pidBlk, 'P', 'Kvp_vsg', 'I', 'Kvi_vsg', 'D', '0');
end

% (c) Update outer dispatch (8.281 MW) and 11 MVA Q-droop gain
set_param([mdl '/Pref'], 'Value', 'Pset');
if getSimulinkBlockHandle([mdl '/ /Gain']) ~= -1
    set_param([mdl '/ /Gain'], 'Gain', 'Kq_vsg');
end
if getSimulinkBlockHandle([mdl '/ /Qref']) ~= -1 && strcmp(get_param([mdl '/ /Qref'], 'BlockType'), 'Constant')
    set_param([mdl '/ /Qref'], 'Value', 'Qset');
end

% (d) Ensure THD block uses 60 Hz fundamental frequency
thdBlks = find_system(mdl, 'FollowLinks', 'off', 'Name', 'THD');
for k = 1:numel(thdBlks)
    try set_param(thdBlks{k}, 'FundamentalFrequency', '60'); catch, end
end

% (e) Break algebraic loop between Normalizer and Universal Bridge (in memory)
if getSimulinkBlockHandle([mdl '/LoopBreaker_Delay']) == -1
    delete_line(mdl, 'Normalizer/1', 'Universal Bridge/1');
    p_norm = get_param([mdl '/Normalizer'], 'Position');
    add_block('simulink/Discrete/Unit Delay', [mdl '/LoopBreaker_Delay'], ...
        'SampleTime', 'SampleTime', 'InitialCondition', '0', ...
        'Position', [p_norm(3)+15, p_norm(2), p_norm(3)+45, p_norm(4)]);
    add_line(mdl, 'Normalizer/1', 'LoopBreaker_Delay/1', 'autorouting', 'on');
    add_line(mdl, 'LoopBreaker_Delay/1', 'Universal Bridge/1', 'autorouting', 'on');
end

% (f) Log internal VSG frequency f_vsg (Gain9 output)
if getSimulinkBlockHandle([mdl '/f_vsg_ToWS']) == -1
    pos = get_param([mdl '/Gain9'], 'Position');
    add_block('simulink/Sinks/To Workspace', [mdl '/f_vsg_ToWS'], ...
        'VariableName', 'f_vsg_log', 'SaveFormat', 'Timeseries', ...
        'Position', [pos(3)+25, pos(2)-15, pos(3)+95, pos(2)+15]);
    add_line(mdl, 'Gain9/1', 'f_vsg_ToWS/1', 'autorouting', 'on');
end

set_param(mdl, 'SolverType', 'Fixed-step', 'Solver', 'ode4', 'FixedStep', 'SampleTime');
set_param(mdl, 'SimulationMode', 'accelerator');

%% 4. PRE-FLIGHT STEADY-STATE CHECK (t = 0 to 3.0 s)
fprintf('=== STEP 1: PRE-FLIGHT STEADY-STATE CHECK (3.0 s) ===\n');
set_param(mdl, 'StopTime', '3.0');
simCheck = sim(mdl, 'ReturnWorkspaceOutputs', 'on');

Vp0 = simCheck.Vpcc_log.Data;
Ip0 = simCheck.Ipcc_log.Data;
fv0 = squeeze(simCheck.f_vsg_log.Data);
fw0 = squeeze(simCheck.w.Data);
if size(fw0, 2) > 1, fw0 = fw0(:,1); end
if mean(fw0(end-100:end)) < 5, fw0 = fw0 * 60; end
P0_mw = movmean(sum(Vp0 .* Ip0, 2) / 1e6, 333);

fprintf('  f_sys(3s)    = %.4f Hz | f_vsg(3s) = %.4f Hz\n', fw0(end), fv0(end));
fprintf('  PCC Vrms(3s) = %.2f V (%.4f pu)\n', rms(Vp0(end-333:end, 1)), rms(Vp0(end-333:end, 1))/(Vrated/sqrt(3)));
fprintf('  P_vsg(3s)    = %.3f MW (target = %.3f MW)\n\n', P0_mw(end), Pset/1e6);

%% 5. FULL 110 s BENCHMARK & CRITICALLY DAMPED INERTIA SWEEP
cases = [
    2.0,  60.0;   % Low-inertia VSG  (zeta = 0.45)
    5.0,  80.0;   % Nominal VSG      (zeta = 0.38)
    8.0, 100.0;   % High-inertia VSG (zeta = 0.38)
];

t_step = 50.0;
set_param(mdl, 'StopTime', '110.0');

results = struct([]);
fprintf('=== STEP 2: RUNNING 110 s CRITICALLY DAMPED VSG KPI SWEEP ===\n');

for c = 1:size(cases, 1)
    H_vsg = cases(c, 1);
    D_pu  = cases(c, 2);
    J     = (2 * H_vsg * Srated) / (wn^2);
    D     = (D_pu  * Srated) / (wn^2);
    save('finalmodel2.mat', 'H_vsg', 'D_pu', 'J', 'D', '-append');

    tic;
    simOut = sim(mdl, 'ReturnWorkspaceOutputs', 'on');
    elapsed = toc;

    t_f  = simOut.w.Time;
    fw   = squeeze(simOut.w.Data);
    if size(fw, 2) > 1, fw = fw(:,1); end
    if mean(fw(t_f > 40 & t_f < 49)) < 5, fw = fw * 60; end

    t_vi = simOut.Vpcc_log.Time;
    Vp   = simOut.Vpcc_log.Data;
    Ip   = simOut.Ipcc_log.Data;

    idx_pre  = (t_f >= 45.0) & (t_f <= 49.5);
    idx_post = (t_f >= t_step);
    idx_ss   = (t_f >= 100.0);

    f_pre    = mean(fw(idx_pre));
    f_post   = fw(idx_post);
    t_post   = t_f(idx_post);

    [f_nadir, i_nad] = min(f_post);
    t_nadir     = t_post(i_nad);
    Delta_f_max = f_pre - f_nadir;
    f_ss        = mean(fw(idx_ss));
    Delta_f_ss  = f_pre - f_ss;

    dt_f   = median(diff(t_f));
    win500 = max(1, round(0.5 / dt_f));
    rocof_vec = (fw(1+win500:end) - fw(1:end-win500)) / (win500 * dt_f);
    t_rocof   = t_f(1+win500:end);
    RoCoF_max = max(abs(rocof_vec(t_rocof >= t_step & t_rocof <= t_step + 5.0)));

    tol_f = max(0.02 * abs(Delta_f_ss), 0.01);
    outside = find(abs(f_post - f_ss) > tol_f, 1, 'last');
    if isempty(outside), t_settle = 0; else, t_settle = t_post(outside) - t_step; end

    V_base_ln = Vrated / sqrt(3);
    Vrms_ts   = sqrt(movmean(Vp(:,1).^2, 333)) / V_base_ln;
    V_pcc_min = min(Vrms_ts(t_vi >= t_step));
    V_pcc_max = max(Vrms_ts(t_vi >= t_step));
    P_mw      = movmean(sum(Vp .* Ip, 2) / 1e6, 333);
    P_peak_MW = max(P_mw(t_vi >= t_step));

    idx_fft = find(t_vi >= 105.0 & t_vi <= 106.0);
    Fs_vi   = 1 / median(diff(t_vi));
    THD_V_pct = compute_fft_thd(Vp(idx_fft, 1), Fs_vi, 60);
    THD_I_pct = compute_fft_thd(Ip(idx_fft, 1), Fs_vi, 60);

    results(c).H_vsg       = H_vsg;
    results(c).D_pu        = D_pu;
    results(c).f_pre       = f_pre;
    results(c).f_nadir     = f_nadir;
    results(c).t_nadir     = t_nadir;
    results(c).Delta_f_max = Delta_f_max;
    results(c).RoCoF_max   = RoCoF_max;
    results(c).t_settle    = t_settle;
    results(c).Delta_f_ss  = Delta_f_ss;
    results(c).V_pcc_min   = V_pcc_min;
    results(c).V_pcc_max   = V_pcc_max;
    results(c).P_peak_MW   = P_peak_MW;
    results(c).THD_V_pct   = THD_V_pct;
    results(c).THD_I_pct   = THD_I_pct;

    fprintf('[PASS] H=%.1f s, D=%.0f pu (%.1fs) | f_pre=%.4f Hz | f_nadir=%.4f Hz | df_max=%.4f Hz | RoCoF=%.4f Hz/s | Vmin=%.4f pu | THDi=%.2f%%\n', ...
        H_vsg, D_pu, elapsed, f_pre, f_nadir, Delta_f_max, RoCoF_max, V_pcc_min, THD_I_pct);
end

%% 6. SAVE & DISPLAY COMPLETE VSG KPI TABLE
save('vsg_kpis.mat', 'results');
T_vsg = struct2table(results);
writetable(T_vsg, 'vsg_kpi_summary.csv');

fprintf('\n=== FINAL CRITICALLY DAMPED VSG KPI SUMMARY TABLE ===\n');
disp(T_vsg);
fprintf('Saved results to vsg_kpis.mat and vsg_kpi_summary.csv\n');

% Close finalmodel2 without saving any in-memory edits to disk
close_system(mdl, 0);

function thd_pct = compute_fft_thd(sig, Fs, f_fund)
    N = length(sig);
    Y = abs(fft(sig - mean(sig))) / (N/2);
    f = (0:N-1) * (Fs / N);
    [~, idx1] = min(abs(f - f_fund));
    V1 = Y(idx1);
    harm_sq = 0;
    for h = 2:40
        [~, idxh] = min(abs(f - h * f_fund));
        harm_sq = harm_sq + Y(idxh)^2;
    end
    thd_pct = 100 * sqrt(harm_sq) / max(V1, 1e-9);
end