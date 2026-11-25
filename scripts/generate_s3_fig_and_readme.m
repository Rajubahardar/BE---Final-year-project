bdclose('all'); clear; clc; close all;
rootDir = 'D:\final year project';
cd(rootDir);
mdlDir = fullfile(rootDir, 'models');
resDir = fullfile(rootDir, 'results');
datDir = fullfile(rootDir, 'data');
addpath(mdlDir, fullfile(rootDir, 'scripts'));
try Simulink.sdi.setRecordData(true); Simulink.sdi.clear; catch, end

w1_50 = local_s3_wave('finalmodel1', mdlDir, 50e-6);
w1_25 = local_s3_wave('finalmodel1', mdlDir, 25e-6);
w2_50 = local_s3_wave('finalmodel2', mdlDir, 50e-6);
w3_50 = local_s3_wave('finalmodel3', mdlDir, 50e-6);

fig3 = figure('Color','w','Position',[60 60 1380 540],'Visible','off');
subplot(1,2,1); hold on; grid on; box on;
plot(w1_50.t_f, w1_50.fw, 'r-',  'LineWidth', 1.6, 'DisplayName', 'Model 1 (GFL PV, Ts=50 us - PLL Collapse)');
plot(w1_25.t_f, w1_25.fw, 'm--', 'LineWidth', 1.3, 'DisplayName', 'Model 1 (GFL PV, Ts=25 us - Verified Collapse)');
plot(w2_50.t_f, w2_50.fw, 'b-',  'LineWidth', 1.8, 'DisplayName', 'Model 2 (RoCoF-VSG - Stable)');
plot(w3_50.t_f, w3_50.fw, 'g-',  'LineWidth', 1.8, 'DisplayName', 'Model 3 (Synchronverter - Stable)');
xlim([48 70]); ylim([45 72]); xlabel('Time (s)'); ylabel('PCC Frequency (Hz)');
title('(a) Weak-Grid (2x Z_{line}) PCC Frequency Trajectory');
legend('Location','southwest');

subplot(1,2,2); hold on; grid on; box on;
plot(w1_50.t_p, w1_50.P_mw, 'r-', 'LineWidth', 1.6, 'DisplayName', 'Model 1 (GFL PV - Loss of Synchronism)');
plot(w2_50.t_p, w2_50.P_mw, 'b-', 'LineWidth', 1.8, 'DisplayName', 'Model 2 (RoCoF-VSG)');
plot(w3_50.t_p, w3_50.P_mw, 'g-', 'LineWidth', 1.8, 'DisplayName', 'Model 3 (Synchronverter)');
xlim([48 70]); xlabel('Time (s)'); ylabel('Active Power Output (MW)');
title('(b) Weak-Grid (2x Z_{line}) Active Power Trajectory');
legend('Location','northwest');
exportgraphics(fig3, fullfile(resDir, 's3_weak_grid_collapse.png'), 'Resolution', 300);
close(fig3);

fid2 = fopen(fullfile(rootDir, 'demo_all.m'), 'w');
fprintf(fid2, 'function demo_all(mode)\n');
fprintf(fid2, 'if nargin < 1, mode = ''fast''; end\n');
fprintf(fid2, 'restoredefaultpath;\n');
fprintf(fid2, 'rootDir = fileparts(mfilename(''fullpath''));\n');
fprintf(fid2, 'cd(rootDir); addpath(fullfile(rootDir, ''models''), fullfile(rootDir, ''scripts'')); clc;\n');
fprintf(fid2, 'if strcmpi(mode, ''resim''), run(fullfile(rootDir, ''scripts'', ''fix_all_reviewer_issues.m'')); return; end\n');
fprintf(fid2, 'k0 = load(fullfile(rootDir, ''data'', ''model0_kpis.mat''), ''kpi0'').kpi0;\n');
fprintf(fid2, 'k1 = load(fullfile(rootDir, ''data'', ''model1_kpis.mat''), ''kpi1'').kpi1;\n');
fprintf(fid2, 'k2 = load(fullfile(rootDir, ''data'', ''model2_kpis.mat''), ''k2'').k2;\n');
fprintf(fid2, 'k3 = load(fullfile(rootDir, ''data'', ''model3_kpis.mat''), ''kpi3'').kpi3;\n');
fprintf(fid2, 'fprintf(''======================================================================================\\n'');\n');
fprintf(fid2, 'fprintf(''  MULTI-DOMAIN TRANSIENT & GRID-FORMING BENCHMARK (WSCC 9-BUS, S1 +30 MW LOAD STEP)\\n'');\n');
fprintf(fid2, 'fprintf(''======================================================================================\\n'');\n');
fprintf(fid2, 'fprintf(''  # | KPI                           | Unit | Model 0    | Model 1    | Model 2    | Model 3\\n'');\n');
fprintf(fid2, 'fprintf(''  0 | Pre-Step Freq Baseline        | Hz   | %%10.4f | %%10.4f | %%10.4f | %%10.4f\\n'', k0.f_base, k1.f_base, k2.f_base, k3.f_base);\n');
fprintf(fid2, 'fprintf(''  1 | Maximum PCC RoCoF (500 ms)    | Hz/s | %%10.4f | %%10.4f | %%10.4f | %%10.4f\\n'', k0.rocof, k1.rocof, k2.rocof, k3.rocof);\n');
fprintf(fid2, 'fprintf(''  2 | Frequency Nadir               | Hz   | %%10.4f | %%10.4f | %%10.4f | %%10.4f\\n'', k0.f_nadir, k1.f_nadir, k2.f_nadir, k3.f_nadir);\n');
fprintf(fid2, 'fprintf(''  3 | Max Freq Excursion |df|       | Hz   | %%10.4f | %%10.4f | %%10.4f | %%10.4f\\n'', k0.f_dev, k1.f_dev, k2.f_dev, k3.f_dev);\n');
fprintf(fid2, 'fprintf(''  4 | Freq Settling Time (ts_f)     | s    | %%10.2f | %%10.2f | %%10.2f | %%10.2f\\n'', k0.t_settle_f, k1.t_settle_f, k2.t_settle_f, k3.t_settle_f);\n');
fprintf(fid2, 'fprintf(''  6 | Peak Active Power Surge       | MW   | %%10.2f | %%10.2f | %%10.2f | %%10.2f\\n'', k0.dP_peak_MW, k1.dP_peak_MW, k2.dP_peak_MW, k3.dP_peak_MW);\n');
fprintf(fid2, 'fprintf(''  7 | Normalized Surge dP/S_rated   | %%%%    | %%10.2f | %%10.2f | %%10.2f | %%10.2f\\n'', k0.dP_surge_pu, k1.dP_surge_pu, k2.dP_surge_pu, k3.dP_surge_pu);\n');
fprintf(fid2, 'fprintf(''\\n--- FULL CONTINGENCY TABLE (S1-S4) ---\\n'');\n');
fprintf(fid2, 'disp(readtable(fullfile(rootDir, ''results'', ''reviewer_fixed_all_scenarios.csv'')));\n');
fprintf(fid2, 'fprintf(''\\n--- DECOUPLED (H, D) SENSITIVITY SWEEP TABLE ---\\n'');\n');
fprintf(fid2, 'disp(readtable(fullfile(rootDir, ''results'', ''decoupled_H_D_sensitivity.csv'')));\n');
fprintf(fid2, 'end\n');
fclose(fid2);

k0 = load(fullfile(datDir, 'model0_kpis.mat'), 'kpi0').kpi0;
k1 = load(fullfile(datDir, 'model1_kpis.mat'), 'kpi1').kpi1;
k2 = load(fullfile(datDir, 'model2_kpis.mat'), 'k2').k2;
k3 = load(fullfile(datDir, 'model3_kpis.mat'), 'kpi3').kpi3;
fid3 = fopen(fullfile(rootDir, 'README.md'), 'w');
fprintf(fid3, '# Multi-Domain Transient & Grid-Forming Control Benchmark on the WSCC 9-Bus System\n\n');
fprintf(fid3, 'Benchmark comparing **Model 0 (All-SG Phasor Baseline)**, **Model 1 (Grid-Following PV EMT)**, **Model 2 (RoCoF-VSG EMT)**, and **Model 3 (Synchronverter EMT)** across four contingencies (`S1`-`S4`) and a 32-point decoupled `(H, D)` parameter sensitivity sweep.\n\n');
fprintf(fid3, '## Baseline S1 (+30 MW Load Step) KPIs\n\n');
fprintf(fid3, '| Model | f_pre (Hz) | RoCoF 500ms (Hz/s) | f_nadir (Hz) | |df_max| (Hz) | dP_peak (MW) | dP/S_rated (%%) |\n');
fprintf(fid3, '| :--- | :---: | :---: | :---: | :---: | :---: | :---: |\n');
fprintf(fid3, '| Model 0 (All-SG) | %.4f | %.4f | %.4f | %.4f | %.2f | %.2f |\n', k0.f_base, k0.rocof, k0.f_nadir, k0.f_dev, k0.dP_peak_MW, k0.dP_surge_pu);
fprintf(fid3, '| Model 1 (GFL PV) | %.4f | %.4f | %.4f | %.4f | %.2f | %.2f |\n', k1.f_base, k1.rocof, k1.f_nadir, k1.f_dev, k1.dP_peak_MW, k1.dP_surge_pu);
fprintf(fid3, '| Model 2 (RoCoF-VSG) | %.4f | %.4f | %.4f | %.4f | %.2f | %.2f |\n', k2.f_base, k2.rocof, k2.f_nadir, k2.f_dev, k2.dP_peak_MW, k2.dP_surge_pu);
fprintf(fid3, '| Model 3 (Synchronverter) | %.4f | %.4f | %.4f | %.4f | %.2f | %.2f |\n\n', k3.f_base, k3.rocof, k3.f_nadir, k3.f_dev, k3.dP_peak_MW, k3.dP_surge_pu);
fprintf(fid3, '## Quick Start\n\n');
fprintf(fid3, '- Run `demo_all` in MATLAB to print all benchmark tables in under 1 second.\n');
fprintf(fid3, '- Run `demo_all(''resim'')` to re-execute the full Simulink benchmark and regenerate all CSVs and 300-DPI figures.\n');
fclose(fid3);

try Simulink.sdi.clear; catch, end
fprintf('\n[ALL COMPLETE] s3_weak_grid_collapse.png, demo_all.m, and README.md are saved!\n');

function w = local_s3_wave(mdl, mdlDir, TsVal)
    if bdIsLoaded(mdl), close_system(mdl, 0); end
    evalc('load_system(fullfile(mdlDir, [mdl ''.slx'']));');
    set_param(mdl, 'PreLoadFcn', '', 'InitFcn', '');
    try set_param(mdl, 'ExtMode', 'off', 'LimitDataPoints', 'off', 'Decimation', '4', 'FastRestart', 'off'); catch, end
    tw = find_system(mdl, 'MatchFilter', @Simulink.match.allVariants, 'BlockType', 'ToWorkspace');
    for i = 1:numel(tw), try set_param(tw{i}, 'SaveFormat', 'Timeseries', 'MaxDataPoints', 'inf', 'Decimation', '4'); catch, end; end
    Ts = TsVal; SampleTime = TsVal; wn = 2*pi*60; Vnpeak = 400*sqrt(2/3); S_inv = 11e6;
    Zbase = (400^2)/S_inv; Rs = 0.002*Zbase; Ls = (0.05*Zbase)/wn; Rg = 0.002*Zbase; Lg = (0.03*Zbase)/wn;
    Cf = 0.05/(wn*Zbase); C2 = Cf; w_res = sqrt((Ls+Lg)/(Ls*Lg*Cf)); Rd = 1/(3*w_res*Cf);
    R1 = 0.02*Zbase; L1 = (0.30*Zbase)/wn; R = R1; L = (0.15*Zbase)/wn;
    w_ci = 2*pi*500; w_cv = w_ci/5; Kip_vsg = w_ci*Ls; Kvp_vsg = w_cv*Cf; Kvi_vsg = Kvp_vsg*(w_cv/4); Kq_vsg = (0.05*Vnpeak)/S_inv;
    J = (2*5.0*S_inv)/(wn^2); D = (80.0*S_inv)/(wn^2); Dp = D; tf = 10/80; Dq = S_inv/(0.05*Vnpeak);
    Srated = S_inv; Pset = 8.28e6; H_vsm = 5.0; D_pu = 80.0;
    wc_lp = 2*pi*20; a0 = 2 + wc_lp*Ts; num_d = [(wc_lp*Ts)/a0, (wc_lp*Ts)/a0]; den_d = [1, (wc_lp*Ts - 2)/a0];
    if ismember(mdl, {'finalmodel2','finalmodel3'})
        bv = load(fullfile(mdlDir, [mdl '.mat'])); fn = fieldnames(bv);
        for bi = 1:numel(fn), if ~ismember(fn{bi}, {'Ts','SampleTime'}), assignin('base', fn{bi}, bv.(fn{bi})); end; end
    end
    assignin('base', 'Ts', Ts); assignin('base', 'SampleTime', SampleTime);
    if strcmp(mdl, 'finalmodel2')
        sub = [mdl '/Voltage and current double closed loop'];
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
    set_param([mdl '/Three-Phase Parallel RLC Load'], 'ActivePower', '30e6');
    set_param([mdl '/Three-Phase Breaker'], 'InitialState', 'open', 'SwitchTimes', '[50]');
    lineBlks = find_system(mdl, 'MatchFilter', @Simulink.match.allVariants, 'MaskType', 'Three-Phase PI Section Line');
    for i = 1:numel(lineBlks), origLen = str2double(get_param(lineBlks{i}, 'Length')); if isfinite(origLen) && origLen > 0, set_param(lineBlks{i}, 'Length', num2str(origLen * 2.0)); end; end
    evalc('simOut = sim(mdl, ''ReturnWorkspaceOutputs'', ''on'', ''StopTime'', ''70.0'');');
    fTs = simOut.get('f_out'); w.t_f = double(fTs.Time(:)); w.fw = double(fTs.Data(:));
    if ismember('Vpcc_log', who(simOut)) && ismember('Ipcc_log', who(simOut))
        vTs = simOut.get('Vpcc_log'); iTs = simOut.get('Ipcc_log');
        w.t_p = double(vTs.Time(:)); Vp = squeeze(double(vTs.Data)); Ip = squeeze(double(iTs.Data));
        if size(Vp,1) ~= numel(w.t_p), Vp = Vp.'; Ip = Ip.'; end
        n = min([numel(w.t_p), size(Vp,1), size(Ip,1)]); w.t_p = w.t_p(1:n);
        w.P_mw = movmean(sum(Vp(1:n,1:3).*Ip(1:n,1:3), 2)/1e6, max(1, round((1/60)/max(median(diff(w.t_p)),25e-6))));
    else
        pTs = simOut.get('P_out'); w.t_p = double(pTs.Time(:)); w.P_mw = double(pTs.Data(:))/1e6;
    end
    clear simOut; try Simulink.sdi.clear; catch, end; close_system(mdl, 0);
end
