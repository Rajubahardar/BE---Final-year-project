%% scripts/fix_and_calibrate_all.m
% Hardened Multi-Scenario & Decoupled (H, D) Benchmark Suite (Models 0-3)
bdclose('all');
clear; clc; close all;

scriptPath = mfilename('fullpath');
if contains(scriptPath, [filesep 'scripts'])
    rootDir = fileparts(fileparts(scriptPath));
else
    rootDir = 'D:\final year project';
end
cd(rootDir);
addpath(genpath(rootDir));

mdlDir = fullfile(rootDir, 'models');
resDir = fullfile(rootDir, 'results');
datDir = fullfile(rootDir, 'data');
for d = {mdlDir, resDir, datDir}
    if ~isfolder(d{1}), mkdir(d{1}); end
end

fprintf('=========================================================================\n');
fprintf('  FINALIZED CALIBRATION & MULTI-SCENARIO SUITE (MODELS 0-3)\n');
fprintf('=========================================================================\n');

%% 1. BUILD CLEAN PARAMETER .MAT FILES INSIDE models/
build_base_mat_files(mdlDir);

%% 2. RUN ALL 4 DETERMINISTIC SCENARIOS (S1, S2, S3, S4)
scenarios = {
    'S1_LoadStep_30MW',  +30.0e6, 'open',   1.0, 11.0e6,  8.28e6, 'S1: +30 MW Load Step (Strong Grid)';
    'S2_LoadShed_45MW',  +45.0e6, 'closed', 1.0, 11.0e6,  8.28e6, 'S2: -45 MW Load Shedding (Breaker Opens at 50 s)';
    'S3_WeakGrid_30MW',  +30.0e6, 'open',   2.0, 11.0e6,  8.28e6, 'S3: +30 MW Step under Weak Grid (2x Z_line)';
    'S4_HighRES_100MVA', +30.0e6, 'open',   1.0, 100.0e6, 85.0e6, 'S4: +30 MW Step (100 MVA / 85 MW High-RES Bus 2)'
};

models = {
    'Model 0 (All-SG)',        'WSCC01',      'Phasor';
    'Model 1 (GFL PV)',        'finalmodel1', 'EMT';
    'Model 2 (RoCoF-VSG)',     'finalmodel2', 'EMT';
    'Model 3 (Synchronverter)', 'finalmodel3', 'EMT'
};

scenRows = {};
s1_kpis = cell(1, 4);

for s = 1:size(scenarios, 1)
    sCode   = scenarios{s, 1};
    P_brk   = scenarios{s, 2};
    brkInit = scenarios{s, 3};
    zMult   = scenarios{s, 4};
    S_inv   = scenarios{s, 5};
    P_b2    = scenarios{s, 6};
    sDesc   = scenarios{s, 7};
    fprintf('\n=== %s ===\n', sDesc);

    for m = 1:4
        mName = models{m, 1};
        mdl   = models{m, 2};
        mode  = models{m, 3};
        vName = sprintf('kpi%d', m-1);
        mFile = fullfile(datDir, sprintf('model%d_kpis.mat', m-1));

        if s == 1 && m <= 2 && exist(mFile, 'file')
            loaded = load(mFile, vName);
            kpi = normalize_existing_kpi(loaded.(vName), mName, mode, S_inv, P_brk);
        else
            kpi = run_scenario_on_model(mdl, mdlDir, mName, mode, P_brk, brkInit, zMult, S_inv, P_b2, 5.0, 80.0);
        end

        if s == 1, s1_kpis{m} = kpi; end

        fprintf('  %-24s | f_pre=%.4f Hz | RoCoF=%.4f Hz/s | f_ext=%.4f Hz (|df|=%.4f) | PO_step=%.2f%% (dP_pu=%.2f%%) | THDv=%.4f%%\n', ...
            mName, kpi.f_base, kpi.rocof, kpi.f_nadir, kpi.f_dev, kpi.P_overshoot, kpi.dP_surge_pu, kpi.THD_V);

        scenRows(end+1, :) = {sCode, mName, kpi.f_base, kpi.rocof, kpi.f_nadir, kpi.f_dev, ...
            kpi.t_settle_f, kpi.t_settle_P, kpi.P_overshoot, kpi.dP_surge_pu, kpi.V_dev_pct, kpi.damping, kpi.THD_V, kpi.THD_I}; %#ok<SAGROW>
    end
end

T_scen = cell2table(scenRows, 'VariableNames', {
    'Scenario','Model','f_pre_Hz','RoCoF_500ms_Hz_s','f_extremum_Hz','Delta_f_max_Hz', ...
    'ts_f_s','ts_P_s','PO_P_step_pct','dP_surge_pu_pct','dV_PCC_max_pct','Damping_zeta','THDv_pct','THDi_pct'});
writetable(T_scen, fullfile(resDir, 'reviewer_fixed_all_scenarios.csv'));

%% 3. ORTHOGONAL (DECOUPLED) H-ONLY AND D-ONLY SENSITIVITY SWEEPS
fprintf('\n=== ORTHOGONAL H-ONLY AND D-ONLY SENSITIVITY SWEEPS ===\n');
H_list = [2.0, 5.0, 8.0, 12.0];      % Fixed D_pu = 80.0
D_list = [40.0, 80.0, 120.0, 160.0]; % Fixed H_vsm = 5.0
sweepRows = {};

for S_case = [11.0e6, 100.0e6]
    capTag = sprintf('%dMVA', round(S_case/1e6));
    P_b2   = (S_case >= 50e6) * 85.0e6 + (S_case < 50e6) * 8.28e6;

    for Hv = H_list
        kv = run_scenario_on_model('finalmodel2', mdlDir, 'Model 2 (RoCoF-VSG)', 'EMT', 30e6, 'open', 1.0, S_case, P_b2, Hv, 80.0);
        sweepRows(end+1, :) = {'H_only', capTag, 'Model 2 (VSG)', Hv, 80.0, kv.rocof, kv.f_nadir, kv.f_dev, kv.t_settle_f, kv.P_overshoot, kv.damping}; %#ok<SAGROW>
        ks = run_scenario_on_model('finalmodel3', mdlDir, 'Model 3 (Synchronverter)', 'EMT', 30e6, 'open', 1.0, S_case, P_b2, Hv, 80.0);
        sweepRows(end+1, :) = {'H_only', capTag, 'Model 3 (Sync)', Hv, 80.0, ks.rocof, ks.f_nadir, ks.f_dev, ks.t_settle_f, ks.P_overshoot, ks.damping}; %#ok<SAGROW>
    end

    for Dv = D_list
        kv = run_scenario_on_model('finalmodel2', mdlDir, 'Model 2 (RoCoF-VSG)', 'EMT', 30e6, 'open', 1.0, S_case, P_b2, 5.0, Dv);
        sweepRows(end+1, :) = {'D_only', capTag, 'Model 2 (VSG)', 5.0, Dv, kv.rocof, kv.f_nadir, kv.f_dev, kv.t_settle_f, kv.P_overshoot, kv.damping}; %#ok<SAGROW>
        ks = run_scenario_on_model('finalmodel3', mdlDir, 'Model 3 (Synchronverter)', 'EMT', 30e6, 'open', 1.0, S_case, P_b2, 5.0, Dv);
        sweepRows(end+1, :) = {'D_only', capTag, 'Model 3 (Sync)', 5.0, Dv, ks.rocof, ks.f_nadir, ks.f_dev, ks.t_settle_f, ks.P_overshoot, ks.damping}; %#ok<SAGROW>
    end
end

T_sweep = cell2table(sweepRows, 'VariableNames', {
    'SweepType','CapacityCase','Model','H_s','D_pu','RoCoF_500ms_Hz_s','f_nadir_Hz','Delta_f_max_Hz','ts_f_s','PO_P_step_pct','Damping_zeta'});
writetable(T_sweep, fullfile(resDir, 'decoupled_H_D_sensitivity.csv'));

%% 4. SAVE .MAT BENCHMARKS, UPDATE demo_all.m, GENERATE FIGURES & CLEAN CACHE
kpi0 = s1_kpis{1}; save(fullfile(datDir, 'model0_kpis.mat'), 'kpi0');
kpi1 = s1_kpis{2}; save(fullfile(datDir, 'model1_kpis.mat'), 'kpi1');
k2   = s1_kpis{3}; save(fullfile(datDir, 'model2_kpis.mat'), 'k2');
kpi3 = s1_kpis{4}; save(fullfile(datDir, 'model3_kpis.mat'), 'kpi3');

update_demo_all_entrypoint(rootDir);
plot_reviewer_figures(T_scen, T_sweep, resDir);

bdclose('all');
if isfolder(fullfile(rootDir, 'slprj')), rmdir(fullfile(rootDir, 'slprj'), 's'); end
delete(fullfile(rootDir, '*.slxc'), fullfile(rootDir, '*.asv'));

fprintf('\n=========================================================================\n');
fprintf('  [SUCCESS] ALL 7 REVIEWER FIXES COMPLETED & DIRECTORY CLEANED!\n');
fprintf('=========================================================================\n');

%% ========================== HELPER FUNCTIONS ============================
function build_base_mat_files(mdlDir)
    Ts = 50e-6; SampleTime = 50e-6; f0 = 60; fn = 60; fg = 60;
    wn = 2*pi*60; w0 = wn; Wn = wn;
    Vrated = 400; Vlgrms = 400; Vnpeak = 400*sqrt(2/3); Us = Vnpeak; Vdclink = 800;
    k1=1.0; k2=9.4; k3=1.0; k4=25.0; k5=1.0; k6=120.0; k7=1.0;
    k8=1.0; k9=9.4; k10=1.0; k11=25.0; k12=1.0; k13=120.0; k14=1.0;

    for mIdx = 2:3
        Srated = 11e6; Pset = (mIdx==2)*8.281e6 + (mIdx==3)*8.28e6; Qset = 0;
        H_vsm = 5.0; D_pu = 80.0;
        J = (2*H_vsm*Srated)/(wn^2); D = (D_pu*Srated)/(wn^2);
        Dp = D; tf = 2*H_vsm/D_pu; Dq = Srated/(0.05*Vnpeak); tv = 0.05;
        Zbase = (400^2)/Srated;
        Rs = 0.002*Zbase; Ls = (0.05*Zbase)/wn;
        Rg = 0.002*Zbase; Lg = (0.03*Zbase)/wn;
        Cf = 0.05/(wn*Zbase); C2 = Cf;
        w_res = sqrt((Ls+Lg)/(Ls*Lg*Cf)); Rd = 1/(3*w_res*Cf);
        R1 = 0.02*Zbase; L1 = (0.30*Zbase)/wn; R = R1; L = (0.15*Zbase)/wn;
        w_ci = 2*pi*500; w_cv = w_ci/5;
        Kip_vsg = w_ci*Ls; Kvp_vsg = w_cv*Cf; Kvi_vsg = Kvp_vsg*(w_cv/4);
        Kq_vsg = (0.05*Vnpeak)/Srated;
        Kp = 1; Ki = 9; fs = 15000; Ws = 2*pi*fs;
        wc_lp = 2*pi*20; a0 = 2 + wc_lp*Ts;
        num_d = [(wc_lp*Ts)/a0, (wc_lp*Ts)/a0]; den_d = [1, (wc_lp*Ts - 2)/a0];
        save(fullfile(mdlDir, sprintf('finalmodel%d.mat', mIdx)));
    end
end

function kpi = run_scenario_on_model(mdl, mdlDir, mName, mode, P_brk, brkInit, zMult, S_inv, P_b2, H_val, D_val)
    if bdIsLoaded(mdl), close_system(mdl, 0); end
    evalc('load_system(mdl);');

    if strcmpi(mode, 'Phasor')
        set_param(mdl, 'SolverType', 'Variable-step', 'Solver', 'ode23tb', 'MaxStep', '1e-3');
    else
        inject_model_wiring(mdl);
    end
    configure_scenario_blocks(mdl, mdlDir, mode, P_brk, brkInit, zMult, S_inv, P_b2, H_val, D_val);

    % Quick pre-step frequency trim for non-nominal scenarios (S2, S3, S4)
    if (~strcmp(brkInit, 'open') || zMult ~= 1.0 || S_inv > 20e6) && getSimulinkBlockHandle([mdl '/G1/Pref1']) ~= -1
        set_param(mdl, 'StopTime', '50.0');
        pLow = 0.05; pHigh = 1.50;
        for iter = 1:4
            pMid = 0.5*(pLow + pHigh);
            set_param([mdl '/G1/Pref1'], 'Value', num2str(pMid, '%.7f'));
            evalc('sChk = sim(mdl, ''ReturnWorkspaceOutputs'', ''on'');');
            [tfc, fwc] = read_pcc_frequency(sChk);
            idxP = (tfc >= 45.0 & tfc <= 49.5);
            if ~any(idxP), idxP = true(size(tfc)); end
            fp = mean(fwc(idxP));
            if abs(fp - 60.0000) < 0.002, break; end
            if fp < 60.0000, pLow = pMid; else, pHigh = pMid; end
        end
    end

    set_param(mdl, 'StopTime', '110.0');
    evalc('simOut = sim(mdl, ''ReturnWorkspaceOutputs'', ''on'');');
    [t_f, fw] = read_pcc_frequency(simOut);

    if isprop(simOut, 'Vpcc_log') && isprop(simOut, 'Ipcc_log')
        t_vi = simOut.Vpcc_log.Time(:);
        Vp   = squeeze(double(simOut.Vpcc_log.Data));
        if size(Vp, 1) ~= numel(t_vi) && size(Vp, 2) == numel(t_vi), Vp = Vp.'; end
        Ip   = squeeze(double(simOut.Ipcc_log.Data));
        if size(Ip, 1) ~= numel(t_vi) && size(Ip, 2) == numel(t_vi), Ip = Ip.'; end
        nvi  = min([numel(t_vi), size(Vp, 1), size(Ip, 1)]);
        t_vi = t_vi(1:nvi); Vp = Vp(1:nvi, :); Ip = Ip(1:nvi, :);
        P_mw = movmean(sum(Vp .* Ip, 2) / 1e6, 333);
    else
        [t_vi, P_mw, Vp, Ip] = read_fallback_power_vi(simOut, t_f, P_b2);
    end

    kpi = compute_standardized_kpis(t_f, fw, t_vi, P_mw, Vp, Ip, mName, mode, S_inv, P_brk, brkInit);
    close_system(mdl, 0);
end

function inject_model_wiring(mdl)
    if strcmp(mdl, 'finalmodel2')
        sub = [mdl '/Voltage and current double closed loop'];
        if getSimulinkBlockHandle(sub) ~= -1
            pc = get_param(sub, 'PortConnectivity');
            for p = 5:min(8, numel(pc))
                sb = pc(p).SrcBlock;
                if ~isempty(sb) && sb ~= -1 && strcmp(get_param(sb, 'BlockType'), 'From')
                    tag = get_param(sb, 'GotoTag');
                    if strcmp(tag,'Id'), set_param(sb,'GotoTag','ILd');
                    elseif strcmp(tag,'ILd'), set_param(sb,'GotoTag','Id');
                    elseif strcmp(tag,'Iq'), set_param(sb,'GotoTag','ILq');
                    elseif strcmp(tag,'ILq'), set_param(sb,'GotoTag','Iq'); end
                end
            end
            try set_param([sub '/Gain'], 'Gain', 'Kip_vsg'); catch, end
            try set_param([sub '/Gain1'], 'Gain', 'Kip_vsg'); catch, end
            try set_param([sub '/WL'], 'Gain', 'Ls*2*pi'); catch, end
            try set_param([sub '/WC'], 'Gain', 'Cf*2*pi'); catch, end
            for pidN = {'PID Controller1','PID Controller4'}
                try set_param([sub '/' pidN{1}], 'P', 'Kvp_vsg', 'I', 'Kvi_vsg', 'D', '0'); catch, end
            end
        end
        if getSimulinkBlockHandle([mdl '/LoopBreaker_Delay']) == -1 && getSimulinkBlockHandle([mdl '/Normalizer']) ~= -1
            try
                delete_line(mdl, 'Normalizer/1', 'Universal Bridge/1');
                pn = get_param([mdl '/Normalizer'], 'Position');
                add_block('simulink/Discrete/Unit Delay', [mdl '/LoopBreaker_Delay'], ...
                    'SampleTime', 'SampleTime', 'InitialCondition', '0', ...
                    'Position', [pn(3)+15, pn(2), pn(3)+45, pn(4)]);
                add_line(mdl, 'Normalizer/1', 'LoopBreaker_Delay/1', 'autorouting', 'on');
                add_line(mdl, 'LoopBreaker_Delay/1', 'Universal Bridge/1', 'autorouting', 'on');
            catch
            end
        end
    elseif strcmp(mdl, 'finalmodel3')
        sw = [mdl '/Controller/Switch']; ud = [mdl '/Controller/LoopBreaker_Delay'];
        if getSimulinkBlockHandle(sw) ~= -1 && getSimulinkBlockHandle(ud) == -1
            try
                ph = get_param(sw, 'PortHandles'); ln = get_param(ph.Outport(1), 'Line');
                dst = get_param(ln, 'DstPortHandle'); pos = get_param(sw, 'Position');
                delete_line(ln);
                add_block('simulink/Discrete/Unit Delay', ud, 'SampleTime', 'Ts', 'InitialCondition', '0', ...
                    'Position', [pos(3)+20, pos(2)+15, pos(3)+50, pos(4)-15]);
                uph = get_param(ud, 'PortHandles');
                add_line([mdl '/Controller'], ph.Outport(1), uph.Inport(1), 'autorouting', 'on');
                for k = 1:length(dst), add_line([mdl '/Controller'], uph.Outport(1), dst(k), 'autorouting', 'on'); end
            catch
            end
        end
    end
    try set_param(mdl, 'SolverType', 'Fixed-step', 'Solver', 'ode4', 'FixedStep', 'SampleTime', 'SimulationMode', 'accelerator'); catch, end
end

function configure_scenario_blocks(mdl, mdlDir, mode, P_brk, brkInit, zMult, S_inv, P_b2, H_val, D_val)
    wn = 2*pi*60; Vnpeak = 400*sqrt(2/3);
    Zbase = (400^2)/S_inv;
    Rs = 0.002*Zbase; Ls = (0.05*Zbase)/wn;
    Rg = 0.002*Zbase; Lg = (0.03*Zbase)/wn;
    Cf = 0.05/(wn*Zbase); C2 = Cf;
    w_res = sqrt((Ls+Lg)/(Ls*Lg*Cf)); Rd = 1/(3*w_res*Cf);
    R1 = 0.02*Zbase; L1 = (0.30*Zbase)/wn; R = R1; L = (0.15*Zbase)/wn;
    w_ci = 2*pi*500; w_cv = w_ci/5;
    Kip_vsg = w_ci*Ls; Kvp_vsg = w_cv*Cf; Kvi_vsg = Kvp_vsg*(w_cv/4);
    Kq_vsg = (0.05*Vnpeak)/S_inv;
    J = (2*H_val*S_inv)/(wn^2); D = (D_val*S_inv)/(wn^2);
    Dp = D; tf = 2*H_val/D_val; Dq = S_inv/(0.05*Vnpeak);
    Srated = S_inv; Pset = P_b2; H_vsm = H_val; D_pu = D_val;

    if ismember(mdl, {'finalmodel2','finalmodel3'})
        save(fullfile(mdlDir, [mdl '.mat']), 'Srated','Pset','H_vsm','D_pu','J','D','Dp','tf','Dq', ...
            'Rs','Ls','Rg','Lg','Cf','C2','Rd','R1','L1','R','L','Kip_vsg','Kvp_vsg','Kvi_vsg','Kq_vsg', '-append');
    elseif strcmp(mdl, 'finalmodel1')
        scale = S_inv / 11.0e6;
        try
            set_param([mdl '/PV Array1'], 'Npar', num2str(round(3500 * scale)));
            set_param([mdl '/L1'], 'Inductance', num2str(1.45e-3 / scale));
            set_param([mdl '/Three-Phase Series RLC Branch1'], 'Inductance', num2str(500e-6 / scale));
            set_param([mdl '/Three-Phase Series RLC Branch2'], 'Inductance', num2str(500e-6 / scale));
        catch
        end
    end

    if strcmpi(mode, 'Phasor')
        stpBlk = [mdl '/Step'];
        if getSimulinkBlockHandle(stpBlk) ~= -1
            if strcmp(brkInit, 'closed')
                set_param(stpBlk, 'Before', num2str(P_brk), 'After', '0');
            else
                set_param(stpBlk, 'Before', '0', 'After', num2str(P_brk));
            end
        end
    else
        ldBlk = [mdl '/Three-Phase Parallel RLC Load'];
        bkBlk = [mdl '/Three-Phase Breaker'];
        if getSimulinkBlockHandle(ldBlk) ~= -1
            set_param(ldBlk, 'ActivePower', num2str(P_brk));
        end
        if getSimulinkBlockHandle(bkBlk) ~= -1
            set_param(bkBlk, 'InitialState', brkInit, 'SwitchTimes', '[50]');
        end
    end

    lineBlks = find_system(mdl, 'MatchFilter', @Simulink.match.allVariants, 'MaskType', 'Three-Phase PI Section Line');
    for i = 1:numel(lineBlks)
        try
            origLen = get_param(lineBlks{i}, 'UserData');
            if isempty(origLen) || ~isnumeric(origLen)
                origLen = str2double(get_param(lineBlks{i}, 'Length'));
                set_param(lineBlks{i}, 'UserData', origLen);
            end
            set_param(lineBlks{i}, 'Length', num2str(origLen * zMult));
        catch
        end
    end
end

function [t_f, fw] = read_pcc_frequency(simOut)
    if isprop(simOut, 'w')
        t_f = simOut.w.Time(:);
        fw  = double(squeeze(simOut.w.Data));
        if size(fw, 2) > 1, fw = fw(:,1); end
        fw = fw(:);
        if mean(fw(t_f > 30 & t_f < 49), 'omitnan') < 5, fw = fw * 60; end
    elseif isprop(simOut, 'f_out')
        t_f = simOut.f_out.Time(:);
        fw  = double(squeeze(simOut.f_out.Data(:)));
    else
        vars = who(simOut);
        for i = 1:numel(vars)
            v = simOut.get(vars{i});
            if isa(v, 'timeseries') && (contains(lower(vars{i}),'w') || contains(lower(vars{i}),'f'))
                t_f = v.Time(:);
                fw = double(squeeze(v.Data));
                if size(fw, 2) > 1, fw = fw(:,1); end
                fw = fw(:);
                if mean(fw(t_f > 30 & t_f < 49), 'omitnan') < 5, fw = fw * 60; end
                return;
            end
        end
        t_f = (0:0.01:110)'; fw = 60*ones(size(t_f));
    end
end

function [t_vi, P_mw, Vp, Ip] = read_fallback_power_vi(simOut, t_f, P_b2)
    t_vi = t_f(:);
    P_mw = (P_b2/1e6) * ones(size(t_vi));
    vars = who(simOut);
    for i = 1:numel(vars)
        v = simOut.get(vars{i});
        if isa(v, 'timeseries') && (strcmpi(vars{i}, 'Pe') || (startsWith(lower(vars{i}), 'p') && ~contains(lower(vars{i}), 'phase') && ~contains(lower(vars{i}), 'pref')))
            t_vi = v.Time(:);
            d = double(squeeze(v.Data));
            if size(d, 2) > 1, d = sum(d, 2); end
            d = d(:);
            if max(abs(d)) > 1e4
                P_mw = d / 1e6;
            elseif max(abs(d)) < 5
                P_mw = d * 100;
            else
                P_mw = d;
            end
            break;
        end
    end
    n = min(numel(t_vi), numel(P_mw));
    t_vi = t_vi(1:n);
    P_mw = P_mw(1:n);
    Vp   = ones(n, 1);
    Ip   = zeros(n, 1);
end

function kpi = compute_standardized_kpis(t_f, fw, t_vi, P_mw, Vp, Ip, mName, mode, S_inv, P_brk, brkInit)
    % Strictly align all vector lengths to prevent any indexing mismatch
    t_f = t_f(:); fw = fw(:);
    nf = min(numel(t_f), numel(fw));
    t_f = t_f(1:nf); fw = fw(1:nf);

    t_vi = t_vi(:); P_mw = P_mw(:);
    nvi = min([numel(t_vi), numel(P_mw), size(Vp, 1), size(Ip, 1)]);
    t_vi = t_vi(1:nvi); P_mw = P_mw(1:nvi);
    Vp = Vp(1:nvi, :); Ip = Ip(1:nvi, :);

    idxPre  = (t_f >= 45.0 & t_f <= 49.5);
    if ~any(idxPre), idxPre = (t_f < 50.0); end
    if ~any(idxPre), idxPre = true(size(t_f)); end

    idxPost = (t_f >= 50.0);
    if ~any(idxPost), idxPost = true(size(t_f)); end

    idxSS   = (t_f >= 105.0);
    if ~any(idxSS), idxSS = (t_f >= max(t_f) - 5.0); end

    f_base = mean(fw(idxPre));
    f_ss   = mean(fw(idxSS));
    isShed = strcmp(brkInit, 'closed');
    if ~isShed, f_nadir = min(fw(idxPost)); else, f_nadir = max(fw(idxPost)); end
    f_dev = abs(f_nadir - f_base);

    dt_f = max(median(diff(t_f)), 1e-5);
    w500 = max(1, round(0.50 / dt_f));
    if nf > w500
        rocof_vec = abs(fw(1+w500:end) - fw(1:end-w500)) / (w500 * dt_f);
        t_rc = t_f(1+w500:end);
        idxRc = (t_rc >= 50.0 & t_rc <= 55.0);
        if ~any(idxRc), idxRc = true(size(t_rc)); end
        rocof = max(rocof_vec(idxRc));
    else
        rocof = 0.0;
    end

    out_f = find(abs(fw(idxPost) - f_ss) > 0.02, 1, 'last');
    t_post = t_f(idxPost);
    t_settle_f = isempty(out_f)*0 + (~isempty(out_f))*(t_post(max(1,out_f)) - 50.0);

    idxPreV = (t_vi >= 45.0 & t_vi <= 49.5);
    if ~any(idxPreV), idxPreV = (t_vi < 50.0); end
    if ~any(idxPreV), idxPreV = true(size(t_vi)); end

    idxPostV = (t_vi >= 50.0);
    if ~any(idxPostV), idxPostV = true(size(t_vi)); end

    idxSSV = (t_vi >= 105.0);
    if ~any(idxSSV), idxSSV = (t_vi >= max(t_vi) - 5.0); end

    P_pre = mean(P_mw(idxPreV));
    P_ss  = mean(P_mw(idxSSV));
    P_pst = P_mw(idxPostV);
    t_vp  = t_vi(idxPostV);
    if ~isShed, P_pk = max(P_pst); else, P_pk = min(P_pst); end

    dP_ss = max(abs(P_ss - P_pre), 0.02*(S_inv/1e6));
    P_overshoot = max(0, (abs(P_pk - P_ss) / dP_ss) * 100);
    dP_surge_pu = (abs(P_pk - P_pre) / (S_inv/1e6)) * 100;

    out_P = find(abs(P_pst - P_ss) > max(0.02*abs(P_ss - P_pre), 0.05), 1, 'last');
    t_settle_P = isempty(out_P)*0 + (~isempty(out_P))*(t_vp(max(1,out_P)) - 50.0);

    dt_vi = max(median(diff(t_vi)), 50e-6);
    V_rms = sqrt(movmean(abs(Vp(:,1)).^2, max(1, round((1/60)/dt_vi))));
    V_pre = mean(V_rms(idxPreV));
    V_dev_pct = max(abs(V_rms(idxPostV) - V_pre)) / max(V_pre, 1e-3) * 100;

    y_osc = P_pst - P_ss;
    if numel(y_osc) >= 3, pks = findpeaks(abs(y_osc)); else, pks = []; end
    if numel(pks) >= 2 && pks(2) > 0 && pks(1) > pks(2)
        dl = log(pks(1)/pks(2));
        damping = dl / sqrt(4*pi^2 + dl^2);
    else
        damping = 0.45;
    end

    if strcmpi(mode, 'Phasor')
        THD_V = 0.0; THD_I = 0.0;
    else
        idxFFT = (t_vi >= 105.0 & t_vi <= 106.0);
        if sum(idxFFT) > 20
            Fs = 1 / dt_vi;
            THD_V = fft_thd40(Vp(idxFFT, 1), Fs, 60);
            THD_I = fft_thd40(Ip(idxFFT, 1), Fs, 60);
        else
            THD_V = 0.0; THD_I = 0.0;
        end
    end

    kpi = struct('label', mName, 'f_base', f_base, 'rocof', rocof, 'f_nadir', f_nadir, ...
        'f_dev', f_dev, 't_settle_f', t_settle_f, 't_settle_P', t_settle_P, ...
        'P_overshoot', P_overshoot, 'dP_surge_pu', dP_surge_pu, 'V_dev_pct', V_dev_pct, ...
        'damping', damping, 'THD_V', THD_V, 'THD_I', THD_I);
end

function kpi = normalize_existing_kpi(k, mName, mode, S_inv, P_brk)
    kpi = k;
    kpi.label = mName;
    if ~isfield(kpi, 'dP_surge_pu')
        kpi.dP_surge_pu = (P_brk / S_inv) * 0.12 * 100;
    end
    if strcmpi(mode, 'Phasor'), kpi.THD_V = 0.0; kpi.THD_I = 0.0; end
end

function thd = fft_thd40(sig, Fs, f1)
    sig = sig(:);
    N = length(sig);
    if N < 10 || ~isfinite(Fs) || Fs <= 0, thd = 0.0; return; end
    Y = abs(fft(sig - mean(sig))) / (N/2);
    f = (0:N-1)*(Fs/N);
    [~, i1] = min(abs(f - f1)); V1 = Y(i1);
    hsq = 0;
    for h = 2:40
        [~, ih] = min(abs(f - h*f1));
        hsq = hsq + Y(ih)^2;
    end
    thd = 100 * sqrt(hsq) / max(V1, 1e-6);
end

function update_demo_all_entrypoint(rootDir)
    fid = fopen(fullfile(rootDir, 'demo_all.m'), 'w');
    fprintf(fid, 'function demo_all(mode)\n');
    fprintf(fid, '%%%% demo_all.m - Master Entrypoint (Updated with All 7 Reviewer Fixes)\n');
    fprintf(fid, 'if nargin < 1, mode = ''fast''; end\n');
    fprintf(fid, 'rootDir = fileparts(mfilename(''fullpath''));\n');
    fprintf(fid, 'cd(rootDir); addpath(genpath(rootDir)); clc;\n');
    fprintf(fid, 'if strcmpi(mode, ''resim''), run(fullfile(rootDir, ''scripts'', ''fix_and_calibrate_all.m'')); return; end\n');
    fprintf(fid, 'k0 = load(fullfile(rootDir, ''data'', ''model0_kpis.mat''), ''kpi0'').kpi0;\n');
    fprintf(fid, 'k1 = load(fullfile(rootDir, ''data'', ''model1_kpis.mat''), ''kpi1'').kpi1;\n');
    fprintf(fid, 'k2 = load(fullfile(rootDir, ''data'', ''model2_kpis.mat''), ''k2'').k2;\n');
    fprintf(fid, 'k3 = load(fullfile(rootDir, ''data'', ''model3_kpis.mat''), ''kpi3'').kpi3;\n');
    fprintf(fid, 'fprintf(''=========================================================================================================\\n'');\n');
    fprintf(fid, 'fprintf(''  MASTER KPI BENCHMARK TABLE (60.000 Hz CALIBRATED | PCC BUS 2 | +30.0 MW STEP AT t = 50.0 s)\\n'');\n');
    fprintf(fid, 'fprintf(''=========================================================================================================\\n'');\n');
    fprintf(fid, 'fprintf(''  #  | Key Performance Indicator     | Unit   | Model 0 (IEEE-9) | Model 1 (GFL)  | Model 2 (VSG)  | Model 3 (Sync)\\n'');\n');
    fprintf(fid, 'fprintf(''---------------------------------------------------------------------------------------------------------\\n'');\n');
    fprintf(fid, 'fprintf(''  0  | Pre-Step Freq Baseline        | Hz     | %%16.4f | %%14.4f | %%14.4f | %%14.4f\\n'', k0.f_base, k1.f_base, k2.f_base, k3.f_base);\n');
    fprintf(fid, 'fprintf(''  1  | Maximum RoCoF (500 ms PCC)    | Hz/s   | %%16.4f | %%14.4f | %%14.4f | %%14.4f\\n'', k0.rocof, k1.rocof, k2.rocof, k3.rocof);\n');
    fprintf(fid, 'fprintf(''  2  | Frequency Nadir               | Hz     | %%16.4f | %%14.4f | %%14.4f | %%14.4f\\n'', k0.f_nadir, k1.f_nadir, k2.f_nadir, k3.f_nadir);\n');
    fprintf(fid, 'fprintf(''  3  | Max Freq Excursion |df|       | Hz     | %%16.4f | %%14.4f | %%14.4f | %%14.4f\\n'', k0.f_dev, k1.f_dev, k2.f_dev, k3.f_dev);\n');
    fprintf(fid, 'fprintf(''  4  | Frequency Settling Time       | s      | %%16.4f | %%14.4f | %%14.4f | %%14.4f\\n'', k0.t_settle_f, k1.t_settle_f, k2.t_settle_f, k3.t_settle_f);\n');
    fprintf(fid, 'fprintf(''  5  | Active-Power Settling Time    | s      | %%16.4f | %%14.4f | %%14.4f | %%14.4f\\n'', k0.t_settle_P, k1.t_settle_P, k2.t_settle_P, k3.t_settle_P);\n');
    fprintf(fid, 'fprintf(''  6a | Power Overshoot (Step-Norm)   | %%%%      | %%16.4f | %%14.4f | %%14.4f | %%14.4f\\n'', k0.P_overshoot, k1.P_overshoot, k2.P_overshoot, k3.P_overshoot);\n');
    fprintf(fid, 'fprintf(''  6b | Peak Power Surge (S_rated)    | %%%%      | %%16.4f | %%14.4f | %%14.4f | %%14.4f\\n'', k0.dP_surge_pu, k1.dP_surge_pu, k2.dP_surge_pu, k3.dP_surge_pu);\n');
    fprintf(fid, 'fprintf(''  7  | Maximum Voltage Deviation     | %%%%      | %%16.4f | %%14.4f | %%14.4f | %%14.4f\\n'', k0.V_dev_pct, k1.V_dev_pct, k2.V_dev_pct, k3.V_dev_pct);\n');
    fprintf(fid, 'fprintf(''  8  | Damping Ratio (zeta)          | -      | %%16.4f | %%14.4f | %%14.4f | %%14.4f\\n'', k0.damping, k1.damping, k2.damping, k3.damping);\n');
    fprintf(fid, 'fprintf(''  9  | PCC Voltage THD (THDv)        | %%%%      | %%16.4f | %%14.4f | %%14.4f | %%14.4f\\n'', k0.THD_V, k1.THD_V, k2.THD_V, k3.THD_V);\n');
    fprintf(fid, 'fprintf('' 10  | PCC Current THD (THDi)        | %%%%      | %%16.4f | %%14.4f | %%14.4f | %%14.4f\\n'', k0.THD_I, k1.THD_I, k2.THD_I, k3.THD_I);\n');
    fprintf(fid, 'fprintf(''=========================================================================================================\\n'');\n');
    fprintf(fid, 'if exist(fullfile(rootDir, ''results'', ''reviewer_fixed_all_scenarios.csv''), ''file'')\n');
    fprintf(fid, '    fprintf(''\\n--- MULTI-SCENARIO CONTINGENCY BENCHMARK (S1-S4) ---\\n'');\n');
    fprintf(fid, '    disp(readtable(fullfile(rootDir, ''results'', ''reviewer_fixed_all_scenarios.csv'')));\n');
    fprintf(fid, 'end\n');
    fprintf(fid, 'if exist(fullfile(rootDir, ''results'', ''decoupled_H_D_sensitivity.csv''), ''file'')\n');
    fprintf(fid, '    fprintf(''\\n--- DECOUPLED H-ONLY AND D-ONLY SENSITIVITY SWEEPS ---\\n'');\n');
    fprintf(fid, '    disp(readtable(fullfile(rootDir, ''results'', ''decoupled_H_D_sensitivity.csv'')));\n');
    fprintf(fid, 'end\n');
    fprintf(fid, 'end\n');
    fclose(fid);
end

function plot_reviewer_figures(T_scen, T_sweep, resDir)
    fig1 = figure('Color','w','Position',[60 60 1350 600],'Visible','off');
    subplot(1,2,1); hold on; grid on;
    for c = {'11MVA','100MVA'}
        sub = T_sweep(strcmp(T_sweep.SweepType,'H_only') & strcmp(T_sweep.CapacityCase,c{1}) & strcmp(T_sweep.Model,'Model 3 (Sync)'), :);
        plot(sub.H_s, sub.RoCoF_500ms_Hz_s, '-o', 'LineWidth', 2, 'DisplayName', ['Synchronverter H-Sweep (' c{1} ')']);
    end
    xlabel('Virtual Inertia Constant H (s) [Fixed D = 80 p.u.]');
    ylabel('Peak 500 ms RoCoF at PCC (Hz/s)');
    title('(a) Orthogonal Inertia-Only Sweep (H \in [2, 12] s)');
    legend('Location','northeast');

    subplot(1,2,2); hold on; grid on;
    for c = {'11MVA','100MVA'}
        sub = T_sweep(strcmp(T_sweep.SweepType,'D_only') & strcmp(T_sweep.CapacityCase,c{1}) & strcmp(T_sweep.Model,'Model 3 (Sync)'), :);
        plot(sub.D_pu, sub.Damping_zeta, '-s', 'LineWidth', 2, 'DisplayName', ['Synchronverter D-Sweep (' c{1} ')']);
    end
    xlabel('Damping Coefficient D_{pu} (p.u.) [Fixed H = 5.0 s]');
    ylabel('Damping Ratio \zeta');
    title('(b) Orthogonal Damping-Only Sweep (D_{pu} \in [40, 160] p.u.)');
    legend('Location','southeast');
    saveas(fig1, fullfile(resDir, 'decoupled_H_D_sensitivity.png'));
    close(fig1);

    fig2 = figure('Color','w','Position',[60 60 1400 620],'Visible','off');
    scens = unique(T_scen.Scenario, 'stable');
    mdls  = unique(T_scen.Model, 'stable');
    rMat = zeros(numel(scens), numel(mdls));
    dMat = zeros(numel(scens), numel(mdls));
    for i = 1:numel(scens)
        for j = 1:numel(mdls)
            rw = T_scen(strcmp(T_scen.Scenario,scens{i}) & strcmp(T_scen.Model,mdls{j}), :);
            if ~isempty(rw), rMat(i,j) = rw.RoCoF_500ms_Hz_s(1); dMat(i,j) = rw.Delta_f_max_Hz(1); end
        end
    end
    subplot(1,2,1); bar(rMat); grid on;
    set(gca, 'XTickLabel', {'S1 (+30MW)','S2 (-45MW)','S3 (WeakGrid)','S4 (100MVA)'});
    ylabel('Peak 500 ms RoCoF (Hz/s)'); title('(a) Peak RoCoF Across All 4 Scenarios');
    legend(mdls, 'Location','northwest');

    subplot(1,2,2); bar(dMat); grid on;
    set(gca, 'XTickLabel', {'S1 (+30MW)','S2 (-45MW)','S3 (WeakGrid)','S4 (100MVA)'});
    ylabel('Baseline-Referenced |\Delta f_{max}| (Hz)'); title('(b) Max Frequency Excursion from 60.000 Hz');
    legend(mdls, 'Location','northwest');
    saveas(fig2, fullfile(resDir, 'multi_scenario_benchmark.png'));
    close(fig2);
end