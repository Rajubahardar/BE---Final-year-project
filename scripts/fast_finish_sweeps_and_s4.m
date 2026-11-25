%% scripts/fast_finish_sweeps_and_s4.m
bdclose('all');
restoredefaultpath;
clear; clc; close all;
rootDir = 'D:\final year project';
cd(rootDir);
addpath(fullfile(rootDir, 'models'), fullfile(rootDir, 'scripts'));
try Simulink.sdi.setRecordData(true); catch, end
try Simulink.sdi.clear; catch, end

mdlDir   = fullfile(rootDir, 'models');
resDir   = fullfile(rootDir, 'results');
datDir   = fullfile(rootDir, 'data');
cacheDir = fullfile(rootDir, '_sim_cache');
if ~isfolder(cacheDir), mkdir(cacheDir); end

T_scen = readtable(fullfile(resDir, 'reviewer_fixed_all_scenarios.csv'));
s1_m2 = T_scen(strcmp(T_scen.Scenario,'S1_LoadStep_30MW') & strcmp(T_scen.Model,'Model 2 (RoCoF-VSG)'), :);
s1_m3 = T_scen(strcmp(T_scen.Scenario,'S1_LoadStep_30MW') & strcmp(T_scen.Model,'Model 3 (Synchronverter)'), :);

%% 1. Re-run S4 (100 MVA) for Models 2 & 3 with InitFcn cleared so 100 MVA params apply
s4Tasks = {
    'Model 2 (RoCoF-VSG)',      'finalmodel2', 100e6, 85e6, 5.0, 80.0;
    'Model 3 (Synchronverter)', 'finalmodel3', 100e6, 85e6, 5.0, 80.0
};
nWorkers = min(2, feature('numcores'));
pool = gcp('nocreate');
if isempty(pool), pool = parpool('Processes', nWorkers); end

s4Kpi = cell(2, 1); s4Pref = nan(2, 1);
parfor idx = 1:2
    wId = 1; try, t = getCurrentTask(); if ~isempty(t), wId = t.ID; end, catch, end
    wCache = fullfile(cacheDir, sprintf('w_%d', wId)); if ~isfolder(wCache), mkdir(wCache); end
    addpath(mdlDir, fullfile(rootDir, 'scripts'));
    Simulink.fileGenControl('set', 'CacheFolder', wCache, 'CodeGenFolder', wCache, 'createDir', true);
    try Simulink.sdi.setRecordData(true); Simulink.sdi.clear; catch, end
    r = s4Tasks(idx, :);
    [kOut, pOut] = run_sweep_point(r{2}, mdlDir, wCache, r{1}, r{3}, r{4}, r{5}, r{6}, NaN);
    s4Kpi{idx} = kOut; s4Pref(idx) = pOut;
    fprintf('[S4 100MVA] %-24s -> f_pre=%.4f | RoCoF=%.4f | |df|=%.4f\n', r{1}, kOut.f_base, kOut.rocof, kOut.f_dev);
end

for idx = 1:2
    k = s4Kpi{idx};
    rowMask = strcmp(T_scen.Scenario,'S4_HighRES_100MVA') & strcmp(T_scen.Model, s4Tasks{idx,1});
    T_scen.Status{rowMask}          = k.status;
    T_scen.f_pre_Hz(rowMask)        = k.f_base;
    T_scen.RoCoF_500ms_Hz_s(rowMask)= k.rocof;
    T_scen.f_extremum_Hz(rowMask)   = k.f_nadir;
    T_scen.Delta_f_max_Hz(rowMask)  = k.f_dev;
    T_scen.ts_f_s(rowMask)          = k.t_settle_f;
    T_scen.ts_P_s(rowMask)          = k.t_settle_P;
    T_scen.dP_peak_MW(rowMask)      = k.dP_peak_MW;
    T_scen.PO_P_step_pct(rowMask)   = k.P_overshoot;
    T_scen.dP_surge_pu_pct(rowMask) = k.dP_surge_pu;
    T_scen.dV_PCC_max_pct(rowMask)  = k.V_dev_pct;
    T_scen.Damping_zeta(rowMask)    = k.damping;
    T_scen.THDv_pct(rowMask)        = k.THD_V;
    T_scen.THDi_pct(rowMask)        = k.THD_I;
end
writetable(T_scen, fullfile(resDir, 'reviewer_fixed_all_scenarios.csv'));

%% 2. Run 32-point Decoupled (H, D) Sweep with 2 Workers & InitFcn Cleared
H_list = [2.0, 5.0, 8.0, 12.0];
D_list = [40.0, 80.0, 120.0, 160.0];
swTasks = {};
for S_case = [11.0e6, 100.0e6]
    capTag = sprintf('%dMVA', round(S_case/1e6));
    if S_case >= 50e6, P_b2 = 85.0e6; p2 = s4Pref(1); p3 = s4Pref(2);
    else, P_b2 = 8.28e6; p2 = NaN; p3 = NaN; end
    for Hv = H_list
        swTasks(end+1, :) = {'H_only', capTag, 'Model 2 (VSG)',  'finalmodel2', S_case, P_b2, Hv, 80.0, p2};
        swTasks(end+1, :) = {'H_only', capTag, 'Model 3 (Sync)', 'finalmodel3', S_case, P_b2, Hv, 80.0, p3};
    end
    for Dv = D_list
        swTasks(end+1, :) = {'D_only', capTag, 'Model 2 (VSG)',  'finalmodel2', S_case, P_b2, 5.0, Dv, NaN};
        swTasks(end+1, :) = {'D_only', capTag, 'Model 3 (Sync)', 'finalmodel3', S_case, P_b2, 5.0, Dv, NaN};
    end
end

nSW = size(swTasks, 1); swRes = cell(nSW, 1);
fprintf('\n=== RUNNING %d DECOUPLED (H, D) SWEEPS (2 WORKERS, LOW-RAM) ===\n', nSW);
parfor idx = 1:nSW
    wId = 1; try, t = getCurrentTask(); if ~isempty(t), wId = t.ID; end, catch, end
    wCache = fullfile(cacheDir, sprintf('w_%d', wId)); if ~isfolder(wCache), mkdir(wCache); end
    addpath(mdlDir, fullfile(rootDir, 'scripts'));
    Simulink.fileGenControl('set', 'CacheFolder', wCache, 'CodeGenFolder', wCache, 'createDir', true);
    try Simulink.sdi.setRecordData(true); Simulink.sdi.clear; catch, end
    r = swTasks(idx, :);
    [kOut, ~] = run_sweep_point(r{4}, mdlDir, wCache, r{3}, r{5}, r{6}, r{7}, r{8}, r{9});
    swRes{idx} = kOut;
    fprintf('  [W%d | %s] %-6s %-6s %-14s H=%4.1f D=%3.0f -> RoCoF=%.4f |df|=%.4f\n', wId, datestr(now,'HH:MM:SS'), r{1}, r{2}, r{3}, r{7}, r{8}, kOut.rocof, kOut.f_dev);
end

sweepCols = {'SweepType','CapacityCase','Model','H_s','D_pu','f_pre_Hz','RoCoF_500ms_Hz_s','f_nadir_Hz','Delta_f_max_Hz','ts_f_s','PO_P_step_pct','dP_surge_pu_pct','Damping_zeta'};
sweepRows = cell(nSW, 13);
for idx = 1:nSW
    r = swTasks(idx, :); k = swRes{idx};
    sweepRows(idx, :) = {r{1}, r{2}, r{3}, r{7}, r{8}, k.f_base, k.rocof, k.f_nadir, k.f_dev, k.t_settle_f, k.P_overshoot, k.dP_surge_pu, k.damping};
end
T_sweep = cell2table(sweepRows, 'VariableNames', sweepCols);
writetable(T_sweep, fullfile(resDir, 'decoupled_H_D_sensitivity.csv'));

%% 3. Save .MAT KPIs and Publication Figures
save_mat_from_table(T_scen, datDir);
plot_sweeps_and_bars(T_scen, T_sweep, resDir);

delete(gcp('nocreate')); bdclose('all'); Simulink.fileGenControl('reset');
try Simulink.sdi.clear; catch, end
if isfolder(cacheDir), try rmdir(cacheDir, 's'); catch, end; end
fprintf('\n[DONE] Genuine (H, D) sweeps, S4 100 MVA, MAT files & PNGs saved!\n');

function [kpi, usedPref] = run_sweep_point(mdl, mdlDir, wCache, mName, S_inv, P_b2, H_val, D_val, fixedPref)
    if bdIsLoaded(mdl), close_system(mdl, 0); end
    evalc('load_system(fullfile(mdlDir, [mdl ''.slx'']));');
    % CRITICAL FIX: Clear PreLoadFcn & InitFcn so sim() does NOT reload static .mat over swept H & D!
    set_param(mdl, 'PreLoadFcn', '', 'InitFcn', '');
    try set_param(mdl, 'ExtMode', 'off', 'LimitDataPoints', 'off', 'Decimation', '4', 'FastRestart', 'off'); catch, end
    tw = find_system(mdl, 'MatchFilter', @Simulink.match.allVariants, 'BlockType', 'ToWorkspace');
    for i = 1:numel(tw), try set_param(tw{i}, 'SaveFormat', 'Timeseries', 'MaxDataPoints', 'inf', 'Decimation', '4'); catch, end; end

    Ts = 50e-6; SampleTime = 50e-6; wn = 2*pi*60; Vnpeak = 400*sqrt(2/3);
    Zbase = (400^2)/S_inv;
    Rs = 0.002*Zbase; Ls = (0.05*Zbase)/wn; Rg = 0.002*Zbase; Lg = (0.03*Zbase)/wn;
    Cf = 0.05/(wn*Zbase); C2 = Cf;
    w_res = sqrt((Ls+Lg)/(Ls*Lg*Cf)); Rd = 1/(3*w_res*Cf);
    R1 = 0.02*Zbase; L1 = (0.30*Zbase)/wn; R = R1; L = (0.15*Zbase)/wn;
    w_ci = 2*pi*500; w_cv = w_ci/5;
    Kip_vsg = w_ci*Ls; Kvp_vsg = w_cv*Cf; Kvi_vsg = Kvp_vsg*(w_cv/4); Kq_vsg = (0.05*Vnpeak)/S_inv;
    J = (2*H_val*S_inv)/(wn^2); D = (D_val*S_inv)/(wn^2);
    Dp = D; tf = 2*H_val/D_val; Dq = S_inv/(0.05*Vnpeak);
    Srated = S_inv; Pset = P_b2; H_vsm = H_val; D_pu = D_val;
    wc_lp = 2*pi*20; a0 = 2 + wc_lp*Ts;
    num_d = [(wc_lp*Ts)/a0, (wc_lp*Ts)/a0]; den_d = [1, (wc_lp*Ts - 2)/a0];

    baseMat = fullfile(mdlDir, [mdl '.mat']);
    wMat    = fullfile(wCache, [mdl '_sw.mat']);
    copyfile(baseMat, wMat, 'f');
    save(wMat, 'Ts','SampleTime','Srated','Pset','H_vsm','D_pu','J','D','Dp','tf','Dq','Rs','Ls','Rg','Lg','Cf','C2','Rd','R1','L1','R','L','Kip_vsg','Kvp_vsg','Kvi_vsg','Kq_vsg','num_d','den_d', '-append');
    bv = load(wMat); fn = fieldnames(bv);
    for bi = 1:numel(fn), assignin('base', fn{bi}, bv.(fn{bi})); end

    if strcmp(mdl, 'finalmodel2')
        sub = [mdl '/Voltage and current double closed loop'];
        if getSimulinkBlockHandle(sub) ~= -1
            pc = get_param(sub, 'PortConnectivity');
            for p = 5:min(8, numel(pc))
                sb = pc(p).SrcBlock;
                if ~isempty(sb) && sb ~= -1 && strcmp(get_param(sb, 'BlockType'), 'From')
                    tg = get_param(sb, 'GotoTag');
                    if strcmp(tg,'Id'), set_param(sb,'GotoTag','ILd'); elseif strcmp(tg,'ILd'), set_param(sb,'GotoTag','Id'); elseif strcmp(tg,'Iq'), set_param(sb,'GotoTag','ILq'); elseif strcmp(tg,'ILq'), set_param(sb,'GotoTag','Iq'); end
                end
            end
            try set_param([sub '/Gain'], 'Gain', 'Kip_vsg'); set_param([sub '/Gain1'], 'Gain', 'Kip_vsg'); set_param([sub '/WL'], 'Gain', 'Ls*2*pi'); set_param([sub '/WC'], 'Gain', 'Cf*2*pi'); catch, end
            for pidN = {'PID Controller1','PID Controller4'}, try set_param([sub '/' pidN{1}], 'P', 'Kvp_vsg', 'I', 'Kvi_vsg', 'D', '0'); catch, end; end
        end
        if getSimulinkBlockHandle([mdl '/LoopBreaker_Delay']) == -1 && getSimulinkBlockHandle([mdl '/Normalizer']) ~= -1
            try delete_line(mdl, 'Normalizer/1', 'Universal Bridge/1'); pn = get_param([mdl '/Normalizer'], 'Position'); add_block('simulink/Discrete/Unit Delay', [mdl '/LoopBreaker_Delay'], 'SampleTime', 'SampleTime', 'InitialCondition', '0', 'Position', [pn(3)+15, pn(2), pn(3)+45, pn(4)]); add_line(mdl, 'Normalizer/1', 'LoopBreaker_Delay/1', 'autorouting', 'on'); add_line(mdl, 'LoopBreaker_Delay/1', 'Universal Bridge/1', 'autorouting', 'on'); catch, end
        end
    elseif strcmp(mdl, 'finalmodel3')
        sw = [mdl '/Controller/Switch']; ud = [mdl '/Controller/LoopBreaker_Delay'];
        if getSimulinkBlockHandle(sw) ~= -1 && getSimulinkBlockHandle(ud) == -1
            try ph = get_param(sw, 'PortHandles'); ln = get_param(ph.Outport(1), 'Line'); dst = get_param(ln, 'DstPortHandle'); pos = get_param(sw, 'Position'); delete_line(ln); add_block('simulink/Discrete/Unit Delay', ud, 'SampleTime', 'Ts', 'InitialCondition', '0', 'Position', [pos(3)+20, pos(2)+15, pos(3)+50, pos(4)-15]); uph = get_param(ud, 'PortHandles'); add_line([mdl '/Controller'], ph.Outport(1), uph.Inport(1), 'autorouting', 'on'); for k = 1:length(dst), add_line([mdl '/Controller'], uph.Outport(1), dst(k), 'autorouting', 'on'); end; catch, end
        end
    end
    try set_param(mdl, 'SolverType', 'Fixed-step', 'Solver', 'ode4', 'FixedStep', 'SampleTime', 'SimulationMode', 'accelerator'); catch, end
    if getSimulinkBlockHandle([mdl '/Three-Phase Parallel RLC Load']) ~= -1, set_param([mdl '/Three-Phase Parallel RLC Load'], 'ActivePower', '30e6'); end
    if getSimulinkBlockHandle([mdl '/Three-Phase Breaker']) ~= -1, set_param([mdl '/Three-Phase Breaker'], 'InitialState', 'open', 'SwitchTimes', '[50]'); end

    usedPref = fixedPref;
    prefBlk = [mdl '/G1/Pref1'];
    if getSimulinkBlockHandle(prefBlk) ~= -1
        if ~isnan(fixedPref)
            set_param(prefBlk, 'Value', num2str(fixedPref, '%.7f'));
        else
            pLow = 0.05; pHigh = 1.60;
            for iter = 1:4
                pMid = 0.5*(pLow + pHigh);
                set_param(prefBlk, 'Value', num2str(pMid, '%.7f'));
                evalc('sChk = sim(mdl, ''ReturnWorkspaceOutputs'', ''on'', ''StopTime'', ''50.0'');');
                fwc = double(sChk.get('f_out').Data(:)); tfc = double(sChk.get('f_out').Time(:));
                idxP = (tfc >= 44.0 & tfc <= 49.5); if ~any(idxP), idxP = true(size(tfc)); end
                fp = mean(fwc(idxP)); usedPref = pMid; clear sChk;
                if abs(fp - 60.0000) < 0.004, break; end
                if fp < 60.0000, pLow = pMid; else, pHigh = pMid; end
            end
        end
    end

    evalc('simOut = sim(mdl, ''ReturnWorkspaceOutputs'', ''on'', ''StopTime'', ''75.0'');');
    fTs = simOut.get('f_out'); t_f = double(fTs.Time(:)); fw = double(fTs.Data(:));
    vTs = simOut.get('Vpcc_log'); iTs = simOut.get('Ipcc_log');
    t_vi = double(vTs.Time(:)); Vp = squeeze(double(vTs.Data)); Ip = squeeze(double(iTs.Data));
    if size(Vp,1) ~= numel(t_vi) && size(Vp,2) == numel(t_vi), Vp = Vp.'; Ip = Ip.'; end
    n = min([numel(t_vi), size(Vp,1), size(Ip,1)]);
    t_vi = t_vi(1:n); Vp = Vp(1:n,1:3); Ip = Ip(1:n,1:3);
    dt_vi = max(median(diff(t_vi)), 25e-6);
    P_mw = movmean(sum(Vp .* Ip, 2) / 1e6, max(1, round((1/60)/dt_vi)));

    idxPre = (t_f >= 45.0 & t_f <= 49.5); idxPost = (t_f >= 50.0); idxSS = (t_f >= 70.0);
    f_base = mean(fw(idxPre)); f_ss = mean(fw(idxSS)); if isempty(fw(idxPost)), f_nadir = NaN; f_dev = NaN; else, f_nadir = min(fw(idxPost)); f_dev = abs(f_nadir - f_base); end
    dt_f = max(median(diff(t_f)), 1e-5); w500 = max(1, round(0.50 / dt_f));
    rocof_vec = abs(fw(1+w500:end) - fw(1:end-w500)) / (w500 * dt_f);
    t_rc = t_f(1+w500:end); idxRc = (t_rc >= 50.0 & t_rc <= 55.0);
    if isempty(rocof_vec), rocof = NaN; else, rocof = max(rocof_vec(idxRc)); end

    idxPreV = (t_vi >= 45.0 & t_vi <= 49.5); idxPostV = (t_vi >= 50.0); idxSSV = (t_vi >= 70.0);
    P_pre = mean(P_mw(idxPreV)); P_ss = mean(P_mw(idxSSV)); P_pk = max(P_mw(idxPostV));
    dP_peak_MW = abs(P_pk - P_pre); dP_surge_pu = (dP_peak_MW / (S_inv/1e6)) * 100.0;
    out_f = find(abs(fw(idxPost) - f_ss) > 0.02, 1, 'last'); t_post = t_f(idxPost);
    if isempty(out_f), t_settle_f = 0.0; else, t_settle_f = max(0.0, t_post(out_f) - 50.0); end
    dP_ss_abs = abs(P_ss - P_pre); tol_P = max(0.02 * dP_ss_abs, 0.05);
    out_P = find(abs(P_mw(idxPostV) - P_ss) > tol_P, 1, 'last'); t_vp = t_vi(idxPostV);
    if isempty(out_P), t_settle_P = 0.0; else, t_settle_P = max(0.0, t_vp(out_P) - 50.0); end
    if dP_ss_abs < 0.05*(S_inv/1e6), P_overshoot = NaN; else, P_overshoot = max(0.0, (abs(P_pk - P_ss)/dP_ss_abs)*100.0); end
    V_rms = sqrt(movmean(abs(Vp(:,1)).^2, max(1, round((1/60)/dt_vi))));
    V_pre = mean(V_rms(idxPreV)); V_dev_pct = max(abs(V_rms(idxPostV) - V_pre)) / max(V_pre, 1e-3) * 100.0;
    idxFFT = (t_vi >= 70.0 & t_vi <= 71.0); Fs = 1/dt_vi;
    THD_V = fft_thd40(Vp(idxFFT,1), Fs, 60); THD_I = fft_thd40(Ip(idxFFT,1), Fs, 60);
    kpi = struct('label', mName, 'status', 'Stable', 'f_base', f_base, 'rocof', rocof, 'f_nadir', f_nadir, 'f_dev', f_dev, 't_settle_f', t_settle_f, 't_settle_P', t_settle_P, 'dP_peak_MW', dP_peak_MW, 'P_overshoot', P_overshoot, 'dP_surge_pu', dP_surge_pu, 'V_dev_pct', V_dev_pct, 'damping', NaN, 'THD_V', THD_V, 'THD_I', THD_I);
    clear simOut Vp Ip;
    try Simulink.sdi.clear; catch, end
    close_system(mdl, 0);
end

function thd = fft_thd40(sig, Fs, f1)
    sig = sig(:); N = length(sig); if N < 20 || ~isfinite(Fs) || Fs <= 0, thd = NaN; return; end; Y = abs(fft(sig - mean(sig))) / (N/2); f = (0:N-1)*(Fs/N);
    [~, i1] = min(abs(f - f1)); V1 = Y(i1); hsq = 0;
    for h = 2:40, [~, ih] = min(abs(f - h*f1)); hsq = hsq + Y(ih).^2; end
    thd = 100 * sqrt(hsq) / max(V1, 1e-6);
end

function save_mat_from_table(T_scen, datDir)
    mNames = {'Model 0 (All-SG)','Model 1 (GFL PV)','Model 2 (RoCoF-VSG)','Model 3 (Synchronverter)'};
    vNames = {'kpi0','kpi1','k2','kpi3'};
    fNames = {'model0_kpis.mat','model1_kpis.mat','model2_kpis.mat','model3_kpis.mat'};
    for i = 1:4
        r = T_scen(strcmp(T_scen.Scenario,'S1_LoadStep_30MW') & strcmp(T_scen.Model,mNames{i}), :);
        st = struct('label',mNames{i},'status',r.Status{1},'f_base',r.f_pre_Hz(1),'rocof',r.RoCoF_500ms_Hz_s(1),'f_nadir',r.f_extremum_Hz(1),'f_dev',r.Delta_f_max_Hz(1),'t_settle_f',r.ts_f_s(1),'t_settle_P',r.ts_P_s(1),'dP_peak_MW',r.dP_peak_MW(1),'P_overshoot',r.PO_P_step_pct(1),'dP_surge_pu',r.dP_surge_pu_pct(1),'V_dev_pct',r.dV_PCC_max_pct(1),'damping',r.Damping_zeta(1),'THD_V',r.THDv_pct(1),'THD_I',r.THDi_pct(1));
        S.(vNames{i}) = st; save(fullfile(datDir, fNames{i}), '-struct', 'S'); clear S;
    end
end

function plot_sweeps_and_bars(T_scen, T_sweep, resDir)
    fig1 = figure('Color','w','Position',[60 60 1350 560],'Visible','off');
    subplot(1,2,1); hold on; grid on; box on;
    for c = {'11MVA','100MVA'}
        s2 = T_sweep(strcmp(T_sweep.SweepType,'H_only') & strcmp(T_sweep.CapacityCase,c{1}) & strcmp(T_sweep.Model,'Model 2 (VSG)'), :);
        s3 = T_sweep(strcmp(T_sweep.SweepType,'H_only') & strcmp(T_sweep.CapacityCase,c{1}) & strcmp(T_sweep.Model,'Model 3 (Sync)'), :);
        plot(s2.H_s, s2.RoCoF_500ms_Hz_s, '-o', 'LineWidth', 1.8, 'DisplayName', ['VSG (' c{1} ')']);
        plot(s3.H_s, s3.RoCoF_500ms_Hz_s, '--s', 'LineWidth', 1.8, 'DisplayName', ['Synchronverter (' c{1} ')']);
    end
    xlabel('Virtual Inertia Constant H (s)  [Fixed D_pu = 80 p.u.]');
    ylabel('Peak 500 ms RoCoF at PCC (Hz/s)'); title('(a) Decoupled Inertia Sweep (H in [2, 12] s)'); legend('Location','best');
    subplot(1,2,2); hold on; grid on; box on;
    for c = {'11MVA','100MVA'}
        s2 = T_sweep(strcmp(T_sweep.SweepType,'D_only') & strcmp(T_sweep.CapacityCase,c{1}) & strcmp(T_sweep.Model,'Model 2 (VSG)'), :);
        s3 = T_sweep(strcmp(T_sweep.SweepType,'D_only') & strcmp(T_sweep.CapacityCase,c{1}) & strcmp(T_sweep.Model,'Model 3 (Sync)'), :);
        plot(s2.D_pu, s2.Delta_f_max_Hz, '-o', 'LineWidth', 1.8, 'DisplayName', ['VSG (' c{1} ')']);
        plot(s3.D_pu, s3.Delta_f_max_Hz, '--s', 'LineWidth', 1.8, 'DisplayName', ['Synchronverter (' c{1} ')']);
    end
    xlabel('Damping Coefficient D_pu (p.u.)  [Fixed H = 5.0 s]');
    ylabel('Max Frequency Excursion |df_max| (Hz)'); title('(b) Decoupled Damping Sweep (D_pu in [40, 160] p.u.)'); legend('Location','best');
    exportgraphics(fig1, fullfile(resDir, 'decoupled_H_D_sensitivity.png'), 'Resolution', 300); close(fig1);

    fig2 = figure('Color','w','Position',[60 60 1380 560],'Visible','off');
    scens = unique(T_scen.Scenario, 'stable'); mdls = unique(T_scen.Model, 'stable');
    rMat = nan(numel(scens), numel(mdls)); dMat = nan(numel(scens), numel(mdls));
    for i = 1:numel(scens), for j = 1:numel(mdls)
        rw = T_scen(strcmp(T_scen.Scenario,scens{i}) & strcmp(T_scen.Model,mdls{j}), :);
        if ~isempty(rw) && strcmp(rw.Status{1}, 'Stable'), rMat(i,j) = rw.RoCoF_500ms_Hz_s(1); dMat(i,j) = rw.Delta_f_max_Hz(1); end
    end; end
    subplot(1,2,1); bar(rMat); grid on; box on; set(gca, 'XTickLabel', {'S1 (+30 MW)','S2 (-45 MW)','S3 (Weak Grid*)','S4 (100 MVA)'});
    ylabel('Peak 500 ms RoCoF at PCC (Hz/s)'); title('(a) Stable PCC RoCoF (*S3 GFL Unstable)'); legend(mdls, 'Location','northwest');
    subplot(1,2,2); bar(dMat); grid on; box on; set(gca, 'XTickLabel', {'S1 (+30 MW)','S2 (-45 MW)','S3 (Weak Grid*)','S4 (100 MVA)'});
    ylabel('Max Frequency Excursion |df_max| (Hz)'); title('(b) Stable Frequency Excursion (*S3 GFL Unstable)'); legend(mdls, 'Location','northwest');
    exportgraphics(fig2, fullfile(resDir, 'multi_scenario_benchmark.png'), 'Resolution', 300); close(fig2);
end
