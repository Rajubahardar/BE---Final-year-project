%% =========================================================================
%  WSCC 9-BUS MODEL 1 - CONSOLIDATED KPI PIPELINE (v5)
%  Model: finalmodel1.slx | Target: Generator 3 (PV bus)
%  Signals (verified in the model): f_out = G3 ROTOR SPEED wm x 60 (Hz), taken
%  inside the G3 subsystem (not a bus or system frequency); P_out = G3 electrical
%  power Pe (pu on the 128 MVA machine base). Expect a larger local RoCoF than
%  the center-of-inertia (swing-equation) value.
%
%  v5 (final): the disturbance is applied at 50 s, after the ~25-30 s start-up
%  transient seen in a no-event run; breaker timing is ENFORCED (error if it does
%  not match cfg.t_step); baseline-quality check; event sanity checks (RoCoF sign
%  and size); console log saved to cfg.out_dir; overshoot withheld while power
%  trends; calibration signature in the raw-file metadata.
%
%  Changes from v2/v3.x:
%   - Power settling time withheld (NaN) while power still trends
%   - Warning if the disturbance size is an assumption, not read from the model
%   - "Dev. from 60 Hz" no longer compared to ref.f_dev (definitions inconsistent)
%   - Raw-signal file stores run metadata; reuse is refused if settings differ
%   - Calibration prints old -> new values (shows whether it changed anything)
%
%  Sequence:
%   1. Configure and run Simulink ONCE
%   2. Extract and validate outputs of the latest run
%   3. Filter frequency and power
%   4. Estimate pre-disturbance drift (single block)
%   5. Keep ORIGINAL filtered frequency; build a SEPARATE drift-compensated
%      trace (diagnostic only)
%   6. Compute every KPI once (one function), for BOTH traces
%   7. Compare against theory (computed) and supplied references (labelled)
%   8. Plot and save
%
%  Requires: MATLAB R2020a or newer (tiledlayout R2019b, exportgraphics R2020a,
%            local functions in scripts R2016b, xline/yline R2018b)
%            Signal Processing Toolbox (butter, filtfilt, findpeaks)
%  Local functions are at the END of this file.
%  =========================================================================
clc;

%% ------------------------------------------------------------------------
%  0. CONFIGURATION (every tunable number lives here)
%  ------------------------------------------------------------------------
cfg = struct();
cfg.mdl               = 'finalmodel1';
cfg.apply_calibration = true;     % true  = apply governor, PV and irradiance calibration
                                  % false = run the model exactly as saved (baseline)
                                  % Run once with each, closing the model in between:
                                  %   close_system('finalmodel1', 0)
cfg.Ts                = 50e-6;    % discrete sample time (s)
cfg.t_stop            = 110.0;    % simulation stop time (s)
cfg.t_step            = 50.0;     % disturbance instant (s). A no-event run showed the model needs ~25-30 s
                                  % to settle after start-up, so the step is applied well after that.
cfg.set_breaker_time  = true;     % true = write cfg.t_step into the breaker's SwitchTimes (in memory only)
cfg.pre_start         = 35.0;     % pre-disturbance window start (s); window = [pre_start, t_step-guard]
                                  % must lie AFTER the start-up transient has flattened (~30 s)
cfg.pre_guard         = 0.1;      % pre window ends t_step - guard (s)
cfg.max_pre_drift     = 0.01;     % baseline counts as settled if |drift across pre window| <= this (Hz)
cfg.fc                = 15.0;     % low-pass cutoff (Hz), zero-phase 2nd order
cfg.fc_alt            = 50.0;     % alternative cutoff for RoCoF sensitivity (Hz)
cfg.auto_resample     = false;    % true = resample non-uniform logs to a uniform grid
                                  % (needed for variable-step logging; default is to fail)
cfg.rocof_win         = 0.1;      % RoCoF regression window after step (s)
cfg.final_win         = 5.0;      % final-value window at end of run (s)
cfg.band_f            = 0.02;     % frequency settling band (+/- Hz)
cfg.band_P_frac       = 0.02;     % power settling band (fraction of net change)
cfg.dwell_s           = 1.0;      % signal must stay in band this long (s)
cfg.min_dP            = 1e-6;     % minimum net power change for P-KPIs
cfg.f_hp              = 0.8;      % high-pass cutoff (Hz) to remove slow trend before damping fit
cfg.damp_win          = 10.0;     % END of damping window, relative to the event; the actual
                                  % window is [t_step+0.5, t_step+damp_win] (9.5 s)
cfg.os_win            = 5.0;      % window after the event for the "early" power overshoot (s)
cfg.reuse_raw         = true;    % true = skip the simulation and re-analyse the raw signals
                                  % saved by an earlier run with the same cfg.tag.
                                  % Refused if t_step, t_stop, Ts or calibration differ.
cfg.f0                = 60.0;     % nominal frequency (Hz)
cfg.S_G3_MVA          = 128.0;    % G3 machine rating (MVA): converts P_out (pu) to MW
cfg.out_dir           = 'C:\Matlab_Workspace';
if ~isfolder(cfg.out_dir), cfg.out_dir = pwd; end
cfg.tag = sprintf('calib%d_t%g', cfg.apply_calibration, cfg.t_step);   % keeps the two runs' files separate

% Calibration values (strings, as set_param expects). Used by the calibration
% block AND stored in the raw-file metadata so reuse can detect a mismatch.
cfg.calib = struct('G1_ref','0.3584', 'G3_ref','0.4689', 'Npar','3500', 'irrad','1000');
if cfg.apply_calibration
    cfg.calib_sig = sprintf('G1=%s;G3=%s;Npar=%s;irrad=%s', ...
        cfg.calib.G1_ref, cfg.calib.G3_ref, cfg.calib.Npar, cfg.calib.irrad);
else
    cfg.calib_sig = 'none';
end

% Keep a copy of the console output so it can be attached or re-read later.
try
    diary off;
    log_file = fullfile(cfg.out_dir, ['console_' cfg.tag '.txt']);
    if isfile(log_file), delete(log_file); end
    diary(log_file);
catch
end

% Swing-equation inputs, READ FROM THE MODEL (synchronous machine blocks,
% 'Mechanical' = [H F p] and 'NominalParameters' = [S V f]):
%   G1: 247.5 MVA, H = 23.64 s | G3: 128 MVA, H = 3.01 s.
% G2 is not a synchronous-machine block (probably the PV/inverter unit): its
% inertia, if any, is NOT counted, so the swing-equation RoCoF is the
% center-of-inertia value for G1 + G3 only.
th.S_sys      = 315.0;            % system base (MVA)
th.P_step_MW  = 30.0;             % fallback only: overwritten by the size read from the model
th.step_source = 'ASSUMED default (not read from model)';
th.H_gen      = [23.64, 3.01];    % G1, G3 inertia constants (s)
th.S_gen      = [247.5, 128];     % G1, G3 ratings (MVA)

% References SUPPLIED from elsewhere (not computed here). They are only
% compared, never mixed into the computed theory. Verify test conditions.
ref = struct( ...
    'rocof',     0.5110, ...   % Hz/s
    'f_nadir',   59.4180, ...  % Hz
    'f_dev',     0.0820, ...   % Hz (definition unconfirmed; kept for traceability)
    't_settle_f',4.1200, ...   % s
    'overshoot', NaN, ...      % pct, supplied 0.00 not compared (definition unconfirmed)
    't_settle_P',NaN, ...      % s, 0.04 s removed (no independent source)
    'zeta',      NaN);

assignin('base','Ts',cfg.Ts);
assignin('base','SampleTime',cfg.Ts);
fprintf('Base workspace: Ts = SampleTime = %.0f us\n', cfg.Ts*1e6);

%% ------------------------------------------------------------------------
%  1. MODEL CALIBRATION (optional) AND SINGLE SIMULATION RUN
%  ------------------------------------------------------------------------
raw_file  = fullfile(cfg.out_dir, ['wscc9_raw_' cfg.tag '.mat']);
use_saved = cfg.reuse_raw && isfile(raw_file);
if cfg.reuse_raw && ~use_saved
    warning('cfg.reuse_raw is true but %s was not found: running the simulation.', raw_file);
end

if use_saved
    fprintf('\n=== REUSING SAVED RAW SIGNALS (no simulation): %s ===\n', raw_file);
    Sraw  = load(raw_file);
    % Refuse stale data: every setting that changes the signals must match.
    if isfield(Sraw, 'meta')
        m = Sraw.meta;  mism = {};
        if abs(m.t_step - cfg.t_step) > 1e-9, mism{end+1} = sprintf('t_step (%.3f vs %.3f)', m.t_step, cfg.t_step); end %#ok<SAGROW>
        if abs(m.t_stop - cfg.t_stop) > 1e-9, mism{end+1} = sprintf('t_stop (%.3f vs %.3f)', m.t_stop, cfg.t_stop); end %#ok<SAGROW>
        if abs(m.Ts - cfg.Ts) > 1e-12,        mism{end+1} = sprintf('Ts (%.3g vs %.3g)', m.Ts, cfg.Ts); end %#ok<SAGROW>
        if m.apply_calibration ~= cfg.apply_calibration
            mism{end+1} = sprintf('apply_calibration (%d vs %d)', m.apply_calibration, cfg.apply_calibration); %#ok<SAGROW>
        end
        if ~isfield(m, 'calib_sig')
            mism{end+1} = 'calibration signature missing (file made by an older script)'; %#ok<SAGROW>
        elseif ~strcmp(m.calib_sig, cfg.calib_sig)
            mism{end+1} = sprintf('calibration values (%s vs %s)', m.calib_sig, cfg.calib_sig); %#ok<SAGROW>
        end
        if ~isempty(mism)
            error('wscc9:staleRaw', ['Saved raw signals were made with different settings: %s. ' ...
                  'Set cfg.reuse_raw = false to re-simulate.'], strjoin(mism, '; '));
        end
        try
            dd = dir(which(cfg.mdl));
            if ~strcmp(dd(1).date, m.model_file_date)
                warning('wscc9:modelChanged', ['Model file date is now %s but the saved signals came from a ' ...
                        'model dated %s: the model may have changed.'], dd(1).date, m.model_file_date);
            end
        catch
        end
        fprintf('Saved file metadata OK (created %s, model file dated %s).\n', m.created, m.model_file_date);
    else
        warning('wscc9:noMeta', ['Saved raw file has no run metadata (made by an older script): ' ...
                'cannot confirm it matches the current settings.']);
    end
    t     = Sraw.t;   f_raw = Sraw.f_raw;
    tP    = Sraw.tP;  P_raw = Sraw.P_raw;
    th.P_step_MW   = Sraw.P_step_MW;
    th.step_source = Sraw.step_source;
else
mdl = cfg.mdl;
if ~bdIsLoaded(mdl), load_system(mdl); end

% --- Breaker timing: must match cfg.t_step, otherwise every KPI is mis-referenced ---
brk = [mdl '/Three-Phase Breaker'];
if strcmp(get_param(mdl, 'Dirty'), 'on')
    warning('wscc9:dirtyModel', ['The loaded model has unsaved in-memory changes (e.g. from an earlier run ' ...
            'or diagnostic). For a clean state run close_system(''%s'', 0) and start again.'], mdl);
end
try
    if cfg.set_breaker_time
        set_param(brk, 'SwitchTimes', sprintf('[%g]', cfg.t_step));
        fprintf('Breaker SwitchTimes set to [%g] (in memory, model file not saved)\n', cfg.t_step);
    end
    sw = str2num(get_param(brk, 'SwitchTimes'));           %#ok<ST2NM>
    fprintf('Breaker switching times: %s | initial state: %s\n', ...
            mat2str(sw), get_param(brk, 'InitialState'));
catch ME
    error('wscc9:breaker', 'Could not set/read the breaker switching time (%s). Fix this before simulating.', ME.message);
end
if isempty(sw) || numel(sw) ~= 1 || abs(sw(1) - cfg.t_step) > 1e-6
    error('wscc9:breakerTiming', ['Breaker switching times %s do not match the single event at ' ...
          'cfg.t_step = %.3f s. Set cfg.set_breaker_time = true or fix the model.'], mat2str(sw), cfg.t_step);
end

% --- Disturbance size (read from the block on the breaker port; NOT verified as the net step) ---
try
    pc = get_param(brk, 'PortConnectivity');
    ii = find(strcmp({pc.Type}, 'RConn1'), 1);
    hh = [pc(ii).SrcBlock; pc(ii).DstBlock];  hh = hh(hh > 0);
    if ~isempty(hh)
        Pload = evalin('base', get_param(hh(1), 'ActivePower'));    % W
        th.P_step_MW   = Pload / 1e6;
        th.step_source = ['read from ' strrep(getfullname(hh(1)), newline, ' ') ...
                          ' (block on breaker port RConn1; model inspection: breaker initially open, other loads fixed)'];
    end
catch ME
    warning('wscc9:disturbanceRead', ...
            'Could not read the disturbance from the model (%s). Keeping %.1f MW.', ...
            ME.message, th.P_step_MW);
end
fprintf('Disturbance size used for theory: %.2f MW (%s)\n', th.P_step_MW, th.step_source);

% --- Report where f_out / P_out come from (verify signal definitions) ---
try
    tw = find_system(mdl, 'MatchFilter', @Simulink.match.allVariants, ...
        'LookUnderMasks','all', 'FollowLinks','on', 'BlockType','ToWorkspace');
    for i = 1:numel(tw)
        vn = get_param(tw{i}, 'VariableName');
        if any(strcmp(vn, {'P_out','f_out'}))
            pcw = get_param(tw{i}, 'PortConnectivity');
            src = pcw(1).SrcBlock;
            if ~isempty(src) && src(1) > 0
                sname = strrep(getfullname(src(1)), newline, ' ');
            else
                sname = '(source not resolved)';
            end
            fprintf('Logged %s <- %s | sample time = %s | decimation = %s\n', vn, sname, ...
                    get_param(tw{i}, 'SampleTime'), get_param(tw{i}, 'Decimation'));
        end
    end
    fprintf('Check that these sources are G3 active power and the intended frequency measurement.\n');
catch ME
    warning('wscc9:logSource', 'Could not inspect the To Workspace blocks: %s', ME.message);
end

if cfg.apply_calibration
    fprintf('\n=== APPLYING MODEL CALIBRATIONS (old -> new, read back from the model) ===\n');

    % Governor mechanical references (Pm0 / Pref)
    gov = {'G1', cfg.calib.G1_ref; 'G3', cfg.calib.G3_ref};
    for k = 1:size(gov,1)
        ok = false;
        for nm = {'Pm0','Pref'}
            blk = [mdl '/' gov{k,1} '/M1: Turbine & Regulators/' nm{1}];
            try
                old_v = get_param(blk, 'Value');
                set_param(blk, 'Value', gov{k,2});
                new_v = get_param(blk, 'Value');
                ok = true;
                fprintf('  %s %s: %s -> %s%s\n', gov{k,1}, nm{1}, old_v, new_v, ...
                        ternary(strcmp(old_v, new_v), '   (UNCHANGED: model already had this value)', ''));
                break;
            catch
            end
        end
        if ~ok
            warning('Could not set governor reference for %s.', gov{k,1});
        end
    end

    % PV array parallel strings
    pv_blks = find_system(mdl, 'MatchFilter', @Simulink.match.allVariants, ...
        'LookUnderMasks','all','FollowLinks','on','Name','PV Array1');
    if ~isempty(pv_blks)
        try
            old_v = get_param(pv_blks{1}, 'Npar');
            set_param(pv_blks{1}, 'Npar', cfg.calib.Npar);
            new_v = get_param(pv_blks{1}, 'Npar');
            fprintf('  PV Array1 Npar: %s -> %s%s\n', old_v, new_v, ...
                    ternary(strcmp(old_v, new_v), '   (UNCHANGED: model already had this value)', ''));
        catch
            warning('Could not set Npar on PV Array1.');
        end
    else
        warning('PV Array1 block not found.');
    end

    % Irradiance constants -> 1000 W/m^2
    cblks = find_system(mdl, 'SearchDepth', 3, 'BlockType', 'Constant');
    n_irr = 0;
    for i = 1:numel(cblks)
        nm = lower(get_param(cblks{i}, 'Name'));
        if contains(nm,'irrad') || contains(nm,'sun')
            try
                old_v = get_param(cblks{i}, 'Value');
                set_param(cblks{i}, 'Value', cfg.calib.irrad);
                n_irr = n_irr + 1;
                fprintf('  %s: %s -> %s\n', strrep(getfullname(cblks{i}), newline, ' '), old_v, cfg.calib.irrad);
            catch
            end
        end
    end
    if n_irr == 0
        fprintf('  No irradiance/sun Constant blocks found (irradiance not changed).\n');
    end
end

fprintf('\n=== RUNNING %.0f-s SIMULATION (ONCE) ===\n', cfg.t_stop);
set_param(mdl, 'StopTime', num2str(cfg.t_stop));
% No save_system here: calibration and StopTime changes stay in memory only,
% so finalmodel1.slx on disk is not overwritten. The script does NOT close the
% model: it stays loaded with these changes active. To discard them, run
% close_system(cfg.mdl, 0) (close without saving) before the next session.
tic;
simOut = sim(mdl);
fprintf('Simulation finished in %.2f s\n', toc);

%% ------------------------------------------------------------------------
%  2. EXTRACT AND VALIDATE (latest run only)
%  ------------------------------------------------------------------------
try
    P_out = simOut.get('P_out');
    f_out = simOut.get('f_out');
catch ME
    error('wscc9:signalRead', ...
          'Could not read P_out / f_out from the latest run: %s', ME.message);
end
if ~isa(P_out,'timeseries') || ~isa(f_out,'timeseries')
    error('P_out and f_out must be timeseries objects.');
end
assignin('base','P_out',P_out);
assignin('base','f_out',f_out);

t     = double(f_out.Time(:));   f_raw = double(squeeze(f_out.Data));  f_raw = f_raw(:);
tP    = double(P_out.Time(:));   P_raw = double(squeeze(P_out.Data));  P_raw = P_raw(:);

% Save the raw logged signals plus run metadata so a later run can set
% cfg.reuse_raw = true and be checked against the settings used here.
P_step_MW = th.P_step_MW;  step_source = th.step_source;
model_file_date = 'unknown';
try
    dd = dir(which(mdl));
    model_file_date = dd(1).date;
catch
end
meta = struct('t_step', cfg.t_step, 't_stop', cfg.t_stop, 'Ts', cfg.Ts, ...
              'apply_calibration', cfg.apply_calibration, 'calib_sig', cfg.calib_sig, ...
              'created', datestr(now, 31), 'model_file_date', model_file_date); %#ok<NASGU,DATST>
save(raw_file, 't', 'f_raw', 'tP', 'P_raw', 'P_step_MW', 'step_source', 'meta', '-v7');
fprintf('Raw signals + metadata saved to %s\n', raw_file);
end   % if use_saved / else (simulation branch)

% The disturbance size must be a verified reading, not the fallback.
if startsWith(th.step_source, 'ASSUMED')
    warning('wscc9:stepAssumed', ['The disturbance size is still an assumption: %.2f MW. ' ...
            'Verify the breaker topology and the net incremental load.'], th.P_step_MW);
end

if numel(t)  ~= numel(f_raw), error('Frequency time/data length mismatch.'); end
if numel(tP) ~= numel(P_raw), error('Power time/data length mismatch.');     end
% Reject invalid samples rather than compressing the time axis.
if any(~isfinite(t)) || any(~isfinite(f_raw))
    error(['Frequency output contains nonfinite timestamps or values. ' ...
           'Inspect the logged signal before filtering.']);
end
if any(~isfinite(tP)) || any(~isfinite(P_raw))
    error(['Power output contains nonfinite timestamps or values. ' ...
           'Inspect the logged signal before filtering.']);
end
if any(diff(t) <= 0) || any(diff(tP) <= 0)
    error('Timestamps must be strictly increasing.');
end

% filtfilt needs a uniform grid. Fail, or (if enabled) resample explicitly.
[t,  f_raw, resF] = ensure_uniform(t,  f_raw, cfg.auto_resample, 'Frequency');
[tP, P_raw, resP] = ensure_uniform(tP, P_raw, cfg.auto_resample, 'Power');
if resF || resP
    warning('Signals were resampled onto a uniform grid (cfg.auto_resample = true).');
end

if t(1) > cfg.pre_start || t(end) < cfg.t_stop - 1e-6
    error('Frequency signal does not cover %.0f-%.0f s (has %.3f-%.3f s).', ...
          cfg.pre_start, cfg.t_stop, t(1), t(end));
end
if tP(1) > cfg.pre_start || tP(end) < cfg.t_stop - 1e-6
    error('Power signal does not cover %.0f-%.0f s (has %.3f-%.3f s).', ...
          cfg.pre_start, cfg.t_stop, tP(1), tP(end));
end

fs_f = 1/median(diff(t));
fs_P = 1/median(diff(tP));
fprintf('\nf_out: %.3f-%.3f s, %d samples, fs = %.1f Hz\n', t(1),  t(end),  numel(t),  fs_f);
fprintf('P_out: %.3f-%.3f s, %d samples, fs = %.1f Hz\n', tP(1), tP(end), numel(tP), fs_P);

%% ------------------------------------------------------------------------
%  3. FILTERING (zero-phase; each signal at its own sample rate)
%  ------------------------------------------------------------------------
% Sample rates here are those of the LOGGED data (after any resampling),
% not cfg.Ts. Confirm the To Workspace sample time / solver settings.
if abs(1/fs_f - cfg.Ts) > 0.01*cfg.Ts
    fprintf('Note: logged frequency step %.3g s differs from cfg.Ts = %.3g s.\n', 1/fs_f, cfg.Ts);
end
if abs(1/fs_P - cfg.Ts) > 0.01*cfg.Ts
    fprintf('Note: logged power step %.3g s differs from cfg.Ts = %.3g s.\n', 1/fs_P, cfg.Ts);
end
if 1/fs_f > cfg.rocof_win/10
    warning(['Frequency step %.3g s is coarse relative to the %.0f-ms RoCoF window ' ...
             '(fewer than 10 samples): the grid may not resolve the event at t_step.'], ...
             1/fs_f, cfg.rocof_win*1e3);
end
if cfg.fc >= fs_f/2 || cfg.fc >= fs_P/2
    error('Primary cutoff %.1f Hz is at or above Nyquist (f: %.1f Hz, P: %.1f Hz).', ...
          cfg.fc, fs_f/2, fs_P/2);
end
if cfg.fc_alt >= fs_f/2
    warning('Alternative cutoff %.1f Hz is not below the frequency Nyquist limit (%.1f Hz); sensitivity run will skip it.', ...
            cfg.fc_alt, fs_f/2);
end
[bF,aF] = butter(2, cfg.fc/(fs_f/2), 'low');
[bP,aP] = butter(2, cfg.fc/(fs_P/2), 'low');

f_filt        = filtfilt(bF, aF, f_raw);
P_filt_native = filtfilt(bP, aP, P_raw);
P_filt        = interp1(tP, P_filt_native, t, 'linear', NaN);   % on frequency time base
if nnz(isfinite(P_filt)) < 10
    error('Too few valid power samples after alignment.');
end
if any(~isfinite(P_filt(t >= cfg.pre_start)))
    warning('%d power samples in the analysis window are NaN after alignment.', ...
            nnz(~isfinite(P_filt(t >= cfg.pre_start))));
end

% NOTE: filtfilt is non-causal; at fc = 15 Hz it smears the step edge and
% can reduce the 100-ms RoCoF. Compare against fc = 50 Hz or unfiltered.

%% ------------------------------------------------------------------------
%  4. DRIFT ESTIMATION (single block) AND 5. SEPARATE COMPENSATED TRACE
%  ------------------------------------------------------------------------
idx_drift = t >= cfg.pre_start & t < cfg.t_step - cfg.pre_guard & isfinite(f_filt);
if nnz(idx_drift) < 10
    error('Too few pre-disturbance samples for drift estimation.');
end
p_drift  = polyfit(t(idx_drift) - cfg.t_step, f_filt(idx_drift), 1);
drift_slope        = p_drift(1);                         % Hz/s
drift_over_window  = drift_slope * (cfg.t_step - cfg.pre_guard - cfg.pre_start);
baseline_at_step   = p_drift(2);                         % fitted f at t_step

% Diagnostic only: remove fitted pre-step trend, keep level at t_step.
% This ASSUMES the pre-step drift would have continued unchanged after the
% event, which the pre-event data cannot establish. Do not treat its nadir
% or settling as a physical response.
f_corr = f_filt - drift_slope .* (t - cfg.t_step);

fprintf('\n=== PRE-DISTURBANCE DRIFT (diagnostic) ===\n');
fprintf('Drift slope                : %+.8f Hz/s\n', drift_slope);
fprintf('Drift across pre window    : %+.6f Hz\n',  drift_over_window);
fprintf('Fitted baseline at t_step  : %.6f Hz\n',   baseline_at_step);
fprintf('Offset from nominal        : %+.6f Hz (%.4f %%)\n', ...
        baseline_at_step - cfg.f0, abs(baseline_at_step - cfg.f0)/cfg.f0*100);
fprintf('The drift is NOT assumed to be an error. Uncorrected KPIs are the\n');
fprintf('primary result; the corrected trace is used for RoCoF sensitivity only.\n');
baseline_ok = abs(drift_over_window) <= cfg.max_pre_drift;
if baseline_ok
    fprintf('Baseline check: PASS (drift %+.4f Hz across the pre window, limit %.4f Hz)\n', ...
            drift_over_window, cfg.max_pre_drift);
else
    warning(['Baseline check FAILED: frequency drifts %+.4f Hz across the pre-disturbance window ' ...
             '(limit %.4f Hz). Deviation, nadir and settling are referenced to an unsettled baseline.'], ...
             drift_over_window, cfg.max_pre_drift);
end

%% ------------------------------------------------------------------------
%  6. KPIs - computed once, same definitions, both traces
%  ------------------------------------------------------------------------
K_un = compute_kpis(t, f_filt, P_filt, cfg, 'UNCORRECTED');   % original filtered frequency
K_co = compute_kpis(t, f_corr, P_filt, cfg, 'DRIFT-COMPENSATED');   % drift-compensated frequency

print_kpis('UNCORRECTED (primary)', K_un);
print_kpis('DRIFT-COMPENSATED (diagnostic: use RoCoF only; nadir/settling are extrapolation-sensitive)', K_co);

% RoCoF sensitivity to filtering (same regression, different pre-processing).
% Report the method with the number; do not pick the largest value.
sens = struct('label',{},'rocof',{});
sens(end+1) = struct('label', sprintf('Filtered, fc = %.0f Hz', cfg.fc), ...
                     'rocof', rocof_regress(t, f_filt, cfg));
if cfg.fc_alt < fs_f/2
    [bA,aA] = butter(2, cfg.fc_alt/(fs_f/2), 'low');
    f_alt = filtfilt(bA, aA, f_raw);
    sens(end+1) = struct('label', sprintf('Filtered, fc = %.0f Hz', cfg.fc_alt), ...
                         'rocof', rocof_regress(t, f_alt, cfg));
else
    warning('fc_alt = %.0f Hz is not below Nyquist (%.1f Hz): skipped.', cfg.fc_alt, fs_f/2);
end
sens(end+1) = struct('label', 'Unfiltered', 'rocof', rocof_regress(t, f_raw, cfg));

fprintf('\n=== RoCoF SENSITIVITY TO FILTERING (%.0f-ms regression, signed) ===\n', cfg.rocof_win*1e3);
for k = 1:numel(sens)
    fprintf('%-26s : %+.6f Hz/s\n', sens(k).label, sens(k).rocof);
end
fprintf('Check the plots around t = %.0f s and confirm the load step occurs there.\n', cfg.t_step);
% Event sanity checks: did a load increase actually happen at t_step?
if ~isfinite(K_un.rocof_signed) || K_un.rocof_abs < 0.05
    warning(['No clear frequency response at t_step (|RoCoF| < 0.05 Hz/s): confirm that the breaker ' ...
             'actually switches the load in at %.1f s.'], cfg.t_step);
elseif K_un.rocof_signed > 0
    warning(['RoCoF is POSITIVE: a load increase should give a negative RoCoF. Check the disturbance ' ...
             'direction and the f_out measurement channel.']);
end

%% ------------------------------------------------------------------------
%  7. THEORY AND COMPARISON
%  ------------------------------------------------------------------------
H_eff        = sum(th.H_gen .* th.S_gen) / th.S_sys;     % s on system base
dPL_pu       = th.P_step_MW / th.S_sys;
rocof_swing_mag    = cfg.f0 * dPL_pu / (2 * H_eff);      % Hz/s, THEORETICAL MAGNITUDE
rocof_swing_signed = -rocof_swing_mag;                   % load increase -> negative RoCoF
rocof_swing        = rocof_swing_mag;                    % used for magnitude comparison

% Effective inertia implied by the measured RoCoF (diagnostic)
H_implied = cfg.f0 * dPL_pu / (2 * K_un.rocof_abs);

fprintf('\n=== THEORY (swing equation, computed - VERIFY INPUTS) ===\n');
fprintf('H_eff = %.4f s | step = %.4f pu\n', H_eff, dPL_pu);
fprintf('Theoretical RoCoF magnitude = %.4f Hz/s (signed: %+.4f Hz/s for a load increase)\n', ...
        rocof_swing_mag, rocof_swing_signed);
fprintf('H implied by simulated RoCoF = %.4f s. A gap to H_eff means the local 100-ms RoCoF is faster than the\n', H_implied);
fprintf('center-of-inertia value (or other inertia/load effects are present); it is not by itself a model error.\n');
fprintf('Disturbance size %.2f MW (%s); reactive part ignored.\n', th.P_step_MW, th.step_source);
fprintf('Assumes: step is a net %.1f MW load increase, no governor/inverter\n', th.P_step_MW);
fprintf('response in the first instant. Only G1 and G3 inertia is counted (G2 / PV inverter inertia is NOT included).\n');
fprintf('Supplied RoCoF reference = %.4f Hz/s (kept separate, not overwritten)\n', ref.rocof);
fprintf('Simulated signed RoCoF (uncorrected) = %+.4f Hz/s\n', K_un.rocof_signed);
fprintf('NOTE: f_out is G3 rotor speed, a LOCAL signal: a RoCoF above the center-of-inertia value is expected.\n');
fprintf('G3 power: baseline %.2f MW, final-window net change %+.2f MW (%.0f %% of the %.0f MW step; provisional while power trends)\n', ...
        K_un.P_base*cfg.S_G3_MVA, K_un.dP*cfg.S_G3_MVA, 100*K_un.dP*cfg.S_G3_MVA/th.P_step_MW, th.P_step_MW);

% Consistency check on the supplied references.
fprintf('\nSupplied-reference consistency check:\n');
fprintf('  f0 - ref.f_nadir = %.4f Hz (deviation from nominal)\n', cfg.f0 - ref.f_nadir);
fprintf('  ref.f_dev        = %.4f Hz (definition not stated)\n', ref.f_dev);
if abs((cfg.f0 - ref.f_nadir) - ref.f_dev) > 0.005
    fprintf('  -> NOT consistent with each other unless the reference baseline was %.4f Hz\n', ...
            ref.f_nadir + ref.f_dev);
    fprintf('     (simulated pre-step baseline: %.4f Hz).\n', K_un.f_base);
end

% Corrected-trace nadir / deviation / settling rely on extrapolating the
% pre-step slope across the whole post-event record, so they are not reported.
% Only the corrected RoCoF (100-ms window) is kept as a diagnostic.
Kc = K_co;
Kc.f_nadir = NaN;  Kc.f_dev_nadir = NaN;  Kc.f_dev_nom = NaN;  Kc.tset_f = NaN;

st_settle_f = ternary(K_un.f_still_moving, 'UNRELIABLE', 'PROVISIONAL');
st_nadir    = ternary(baseline_ok, 'ESTIMATE', 'PROVISIONAL');
st_settle_P = ternary(K_un.P_still_moving, 'UNRELIABLE', ...
                      ternary(isnan(K_un.tset_P), 'UNAVAILABLE', 'PROVISIONAL'));
st_os       = ternary(K_un.P_still_moving, 'UNRELIABLE', 'PROVISIONAL');

% Row: label | uncorrected | corrected | reference | diff mode | ref type | status
% "Dev. from 60 Hz" has NO reference: ref.f_dev (0.082) is inconsistent with
% ref.f_nadir under that definition, so no comparison is made.
rows = { ...
  'RoCoF vs swing eq, COI (Hz/s)', K_un.rocof_abs,      Kc.rocof_abs,      rocof_swing,     'pct', 'COMPUTED',          'ESTIMATE'; ...
  'RoCoF magnitude vs supplied (Hz/s)', K_un.rocof_abs,      Kc.rocof_abs,      ref.rocof,       'pct', 'SUPPLIED',          'ESTIMATE'; ...
  'Frequency nadir (Hz)',               K_un.f_nadir,        Kc.f_nadir,        ref.f_nadir,     'abs', 'SUPPLIED',          st_nadir; ...
  'Dev. from baseline (Hz)',            K_un.f_dev_nadir,    Kc.f_dev_nadir,    ref.f_dev,       'abs', 'DEF UNCONFIRMED',   'PROVISIONAL'; ...
  'Dev. from 60 Hz (Hz)',               K_un.f_dev_nom,      Kc.f_dev_nom,      NaN,             'abs', 'NO COMPARABLE REF', 'NOT COMPARED'; ...
  'Freq. settling (s)',                 K_un.tset_f,         Kc.tset_f,         ref.t_settle_f,  'pct', 'SUPPLIED',          st_settle_f; ...
  'Power overshoot, whole record (%)',  K_un.overshoot_reported, Kc.overshoot_reported, ref.overshoot,   'abs', 'NO REF',            st_os; ...
  sprintf('Power overshoot, first %.0f s (%%)', cfg.os_win), ...
                                        K_un.overshoot_early_reported, Kc.overshoot_early_reported, NaN,           'abs', 'NO REF',            st_os; ...
  'Power settling (s)',                 K_un.tset_P,         Kc.tset_P,         ref.t_settle_P,  'pct', 'NO REF',            st_settle_P; ...
  'Damping ratio',                      K_un.zeta,           Kc.zeta,           ref.zeta,        'abs', 'NO REF',            ternary(isnan(K_un.zeta), 'UNAVAILABLE', 'INDICATIVE')};

W = 148;
fprintf('\n*** Verified by model inspection: breaker timing, 30 MW load step, f_out = G3 rotor speed (Hz),\n');
fprintf('*** P_out = G3 electrical power (pu on %.0f MVA). NOT verified: the supplied references'' test\n', cfg.S_G3_MVA);
fprintf('*** conditions and definitions. Calibration applied: %d\n', cfg.apply_calibration);
fprintf('\n%s\n', repmat('=',1,W));
fprintf('%-36s | %12s | %12s | %12s | %10s | %10s | %-18s | %-12s\n', ...
        'KPI','Sim (uncorr)','Sim (corr)','Reference','Diff unc','Diff cor','Ref type','Status');
fprintf('%s\n', repmat('-',1,W));
for r = 1:size(rows,1)
    fprintf('%-36s | %12.4f | %12.4f | %12.4f | %10s | %10s | %-18s | %-12s\n', ...
        rows{r,1}, rows{r,2}, rows{r,3}, rows{r,4}, ...
        fmt_err(rows{r,2}, rows{r,4}, rows{r,5}), fmt_err(rows{r,3}, rows{r,4}, rows{r,5}), ...
        rows{r,6}, rows{r,7});
end
fprintf('%s\n', repmat('=',1,W));
fprintf('Diff: RoCoF and settling rows show percent difference from the reference; all other rows\n');
fprintf('show the absolute difference in the row unit (Hz, %% or ratio). N/A = no reference or value.\n');
fprintf('Corrected-trace nadir, deviation and settling are N/A: they depend on extrapolating the\n');
fprintf('pre-step slope over the whole record. Only the corrected RoCoF is kept as a diagnostic.\n');
fprintf('Frequency nadir diff is in Hz (absolute), not percent of 59 Hz.\n');
fprintf('Status: ESTIMATE = measured, reference conditions unconfirmed; PROVISIONAL = depends on unverified\n');
fprintf('definitions or a still-moving baseline; UNRELIABLE = final-window signal still trending;\n');
fprintf('INDICATIVE = rough diagnostic; UNAVAILABLE = not computed; NOT COMPARED = no valid reference.\n');
if K_un.P_still_moving
    fprintf('Power is still trending at the end of the record: power settling is withheld and the\n');
    fprintf('overshoot is withheld (NaN above); provisional values are in the KPI summary.\n');
end

fprintf('\n=== BASELINE METRICS (reported separately) ===\n');
fprintf('Offset from nominal (uncorrected) : %+.6f Hz = %.4f %%\n', ...
        K_un.f_base - cfg.f0, abs(K_un.f_base - cfg.f0)/cfg.f0*100);
fprintf('Pre-step drift rate               : %+.8f Hz/s\n', drift_slope);

%% ------------------------------------------------------------------------
% Added automatically: smoothed power settling and overshoot analysis
P_analysis = wscc9_power_settling_overshoot(t, P_filt, cfg);

%  8. PLOTS AND SAVING
%  ------------------------------------------------------------------------
% Drift diagnostic
fig1 = figure('Name','Drift diagnostic','Color','w');
plot(t, f_filt, 'b', 'DisplayName','Original filtered'); hold on;
plot(t, f_corr, 'r', 'DisplayName','Drift-compensated (diagnostic)');
plot(t(idx_drift), polyval(p_drift, t(idx_drift)-cfg.t_step), 'k--', ...
     'LineWidth',1.5, 'DisplayName','Pre-step linear fit');
xline(cfg.t_step,'--','Load step');
grid on; xlim([cfg.pre_start cfg.t_stop]);
xlabel('Time (s)'); ylabel('Frequency (Hz)');
title('Pre-disturbance drift estimate'); legend('Location','best');

% Response figure
has_power = any(isfinite(P_filt));
fig2 = figure('Name','Disturbance response','Color','w','Position',[100 60 1100 850]);
tl = tiledlayout(fig2,3,1,'TileSpacing','compact','Padding','compact'); %#ok<NASGU>

nexttile;
if has_power
    plot(t, P_filt, 'b', 'LineWidth',1.2); hold on;
    xline(cfg.t_step,'r--','Load step');
    yline(K_un.P_post,':','Final mean');
    ylabel('G3 electrical power (pu on machine base)');
    title('Generator 3 electrical power (filtered)');
    grid on; xlim([0 cfg.t_stop]);
else
    axis off; title('G3 power unavailable');
end

nexttile;
plot(t, f_raw,  'Color',[0.75 0.75 0.75], 'DisplayName','Raw'); hold on;
plot(t, f_filt, 'b', 'LineWidth',1.2, 'DisplayName','Filtered');
plot(t, f_corr, 'r', 'LineWidth',1.0, 'DisplayName','Drift-compensated');
yline(cfg.f0,':','Nominal','HandleVisibility','off');
xline(cfg.t_step,'r--','Load step','HandleVisibility','off');
grid on; xlim([0 cfg.t_stop]);
ylabel('G3 rotor speed (Hz)'); title('G3 rotor speed as frequency'); legend('Location','best');

nexttile;
plot(t, f_filt - K_un.f_base, 'm', 'LineWidth',1.2, 'DisplayName','Uncorrected'); hold on;
plot(t, f_corr - K_co.f_base, 'r', 'LineWidth',1.0, 'DisplayName','Compensated');
yline(0,'k:','HandleVisibility','off');
xline(cfg.t_step,'r--','Load step','HandleVisibility','off');
grid on; xlim([0 cfg.t_stop]);
xlabel('Time (s)'); ylabel('\Delta f (Hz)');
title('Deviation from each trace''s own pre-step baseline'); legend('Location','best');

% Zoom around the load step: confirm timing and size of the disturbance
fig3 = figure('Name','Zoom at load step','Color','w','Position',[120 80 1000 600]);
zw = [cfg.t_step - 0.5, cfg.t_step + 1.5];
tiledlayout(fig3,2,1,'TileSpacing','compact','Padding','compact');
nexttile;
plot(t, f_raw, 'Color',[0.7 0.7 0.7]); hold on; plot(t, f_filt, 'b','LineWidth',1.2);
xline(cfg.t_step,'r--','t_{step}'); xlim(zw); grid on;
ylabel('Frequency (Hz)'); title('Frequency around the load step'); legend('Raw','Filtered','Location','best');
nexttile;
plot(tP, P_raw, 'Color',[0.7 0.7 0.7]); hold on; plot(t, P_filt, 'b','LineWidth',1.2);
xline(cfg.t_step,'r--','t_{step}'); xlim(zw); grid on;
xlabel('Time (s)'); ylabel('P_{out} (pu)'); title('Power around the load step');

% Save everything
results = struct('cfg',cfg, 'time',t, 'f_raw',f_raw, 'f_filt',f_filt, ...
    'f_corr',f_corr, 'P_filt',P_filt, 'drift_slope_Hz_s',drift_slope, ...
    'baseline_at_step_Hz',baseline_at_step, 'KPI_uncorrected',K_un, ...
    'KPI_corrected',K_co, 'rocof_sensitivity',sens, 'rocof_swing_Hz_s',rocof_swing, ...
    'H_eff_s',H_eff, 'H_implied_s',H_implied, 'theory_inputs',th, 'supplied_refs',ref);
results.power_analysis = P_analysis;
save(fullfile(cfg.out_dir, ['wscc9_kpi_results_' cfg.tag '.mat']), 'results', '-v7');
exportgraphics(fig1, fullfile(cfg.out_dir, ['drift_diagnostic_' cfg.tag '.png']), 'Resolution',180);
exportgraphics(fig2, fullfile(cfg.out_dir, ['response_'         cfg.tag '.png']), 'Resolution',200);
exportgraphics(fig3, fullfile(cfg.out_dir, ['zoom_load_step_'   cfg.tag '.png']), 'Resolution',200);
fprintf('\n[OK] Results and plots saved to %s\n', cfg.out_dir);
try, diary off; catch, end

%% =========================================================================
%  LOCAL FUNCTIONS
%  =========================================================================
function K = compute_kpis(t, f, P, cfg, label)
    ts      = cfg.t_step;
    idx_pre = t >= cfg.pre_start & t < ts - cfg.pre_guard;
    idx_ev  = t >= ts;
    idx_fin = t >= max(ts, t(end) - cfg.final_win) & t <= t(end);

    fpre = f(idx_pre & isfinite(f));
    Ppre = P(idx_pre & isfinite(P));
    if numel(fpre) < 10, error('Insufficient valid pre-step frequency samples.'); end
    if numel(Ppre) < 10, error('Insufficient valid pre-step power samples.'); end

    Pfin = P(idx_fin & isfinite(P));
    if numel(Pfin) < 10, error('Insufficient valid final-window power samples.'); end
    if nnz(idx_fin & isfinite(f)) < 10
        error('Insufficient valid final-window frequency samples.');
    end

    K = struct();
    K.f_base = mean(fpre);
    K.P_base = mean(Ppre);

    % RoCoF: signed linear regression over the first rocof_win seconds
    idx_r = idx_ev & t <= ts + cfg.rocof_win & isfinite(f);
    if nnz(idx_r) >= 5
        pr = polyfit(t(idx_r) - ts, f(idx_r), 1);
        K.rocof_signed = pr(1);
    else
        K.rocof_signed = NaN;
        warning('Too few samples in the RoCoF window.');
    end
    K.rocof_abs = abs(K.rocof_signed);

    % Nadir and peak: use only finite post-disturbance samples
    idx_ev_valid = t >= ts & isfinite(f);
    fe = f(idx_ev_valid);
    te = t(idx_ev_valid);
    if isempty(fe)
        error('No finite post-disturbance frequency samples.');
    end
    [K.f_nadir, i] = min(fe);   K.t_nadir  = te(i);
    [K.f_peak,  j] = max(fe);   K.t_peak_f = te(j);
    K.f_dev_nadir  = K.f_base - K.f_nadir;           % from PRE-STEP BASELINE, positive = dip
    K.f_dev_nom    = cfg.f0  - K.f_nadir;            % from NOMINAL 60 Hz, positive = below nominal
    K.f_dev_maxabs = max(abs(fe - K.f_base));

    % Final values
    K.f_post = mean(f(idx_fin & isfinite(f)));
    K.P_post = mean(Pfin);

    % Final-window trend check: settling is judged against the final-window
    % mean, which is only meaningful if the signal has stopped moving.
    fi = idx_fin & isfinite(f);
    pf = polyfit(t(fi) - t(end), f(fi), 1);
    K.f_final_slope = pf(1);                                  % Hz/s
    K.f_still_moving = abs(pf(1)) * cfg.final_win > 0.5 * cfg.band_f;
    if K.f_still_moving
        warning(['[%s] Frequency is still trending in the final %.0f s (%+.5f Hz/s, ' ...
                 '%.4f Hz over the window): settling time is unreliable.'], ...
                 label, cfg.final_win, pf(1), pf(1)*cfg.final_win);
    end

    % Frequency settling (one algorithm for all signals)
    K.tset_f_prov = settle_time(t, f, K.f_post, cfg.band_f, ts, cfg.dwell_s);  % algorithmic estimate
    % Reported settling time is withheld while the final window still trends.
    K.tset_f = ternary(K.f_still_moving, NaN, K.tset_f_prov);

    % Power KPIs
    K.dP = K.P_post - K.P_base;
    adP  = abs(K.dP);
    K.P_final_slope = NaN;  K.P_still_moving = false;
    K.tset_P = NaN; K.tset_P_prov = NaN;
    K.overshoot = NaN; K.overshoot_early = NaN; K.excursion_pct = NaN;
    K.overshoot_reported = NaN; K.overshoot_early_reported = NaN;
    K.P_peak = NaN; K.t_peak_P = NaN; K.zeta = NaN; K.n_peaks = 0; K.f_osc = NaN;

    Pe = P(idx_ev & isfinite(P)); tPe = t(idx_ev & isfinite(P));
    if ~isempty(Pe)
        [K.P_peak, k] = max(Pe); K.t_peak_P = tPe(k);
    end
    if adP > cfg.min_dP && ~isempty(Pe)
        K.tset_P_prov = settle_time(t, P, K.P_post, cfg.band_P_frac*adP, ts, cfg.dwell_s);
        K.tset_P      = K.tset_P_prov;

        % Same rule as frequency: withhold settling while power still trends.
        Pi = idx_fin & isfinite(P);
        pp = polyfit(t(Pi) - t(end), P(Pi), 1);
        K.P_final_slope  = pp(1);
        K.P_still_moving = abs(pp(1)) * cfg.final_win > 0.5 * cfg.band_P_frac * adP;
        if K.P_still_moving
            warning(['[%s] Power is still trending in the final %.0f s: power settling time ' ...
                     'and overshoot (vs final mean) are unreliable.'], label, cfg.final_win);
            K.tset_P = NaN;
        end

        % Overshoot definition (this script's own, not a control-theory
        % standard): largest excursion PAST the final-window mean, in the
        % direction of the net power change, as % of |net change|.
        % A post-step power peak can have a physical meaning different from
        % control-system overshoot; do not compare to an external value
        % unless that value uses the same definition.
        exc = max(0, max(sign(K.dP) .* (Pe - K.P_post)));
        K.overshoot     = 100 * exc / adP;
        K.excursion_pct = 100 * exc / max(abs(K.P_base), 1e-6);
        % Same definition, but only within the first cfg.os_win seconds after the event
        we = tPe <= ts + cfg.os_win;
        if any(we)
            exc_e = max(0, max(sign(K.dP) .* (Pe(we) - K.P_post)));
            K.overshoot_early = 100 * exc_e / adP;
        end
        % Overshoot is measured against the final-window mean, so it is only
        % REPORTED once power has stopped trending. The raw values stay in
        % K.overshoot / K.overshoot_early as provisional diagnostics.
        if K.P_still_moving
            K.overshoot_reported = NaN;  K.overshoot_early_reported = NaN;
        else
            K.overshoot_reported = K.overshoot;  K.overshoot_early_reported = K.overshoot_early;
        end
        [K.zeta, K.n_peaks, K.f_osc] = damping_estimate(t, P, ts, cfg);
    else
        warning('Net power change too small: power KPIs set to NaN.');
    end
end

function tset = settle_time(t, x, xf, band, ts, dwell)
% Time after ts at which x last leaves +/- band around xf and stays inside
% for at least 'dwell' seconds until the end of the record.
    idx = t >= ts;
    tt = t(idx); xx = x(idx);
    out = ~isfinite(xx) | abs(xx - xf) > band;
    k = find(out, 1, 'last');
    if isempty(k)
        tset = 0;
    elseif k == numel(tt) || (tt(end) - tt(k+1)) < dwell
        tset = NaN;                      % not demonstrably settled
    else
        tset = tt(k+1) - ts;
    end
end

function [zeta, n, f_osc] = damping_estimate(t, P, ts, cfg)
% INDICATIVE damping of the post-event power oscillation.
%  1) zero-phase high-pass (cfg.f_hp) removes the slow recovery trend
%  2) positive peaks of the oscillatory part in [ts+0.5, ts+cfg.damp_win]
%  3) ln(peak) is fitted against time: sigma = decay rate; f_osc from peak spacing
%  4) zeta = sigma / sqrt(sigma^2 + wd^2), wd = 2*pi*f_osc
% Returned only with >= 5 peaks and a fit R^2 >= 0.7. A single mode is NOT
% proven: confirm with Prony / FFT before quoting zeta.
    zeta = NaN; n = 0; f_osc = NaN;
    if any(~isfinite(P)), return; end
    fs = 1 / median(diff(t));
    if cfg.f_hp >= fs/2, return; end
    [b, a] = butter(2, cfg.f_hp/(fs/2), 'high');
    x = filtfilt(b, a, P);
    w = t >= ts + 0.5 & t <= ts + cfg.damp_win;
    if nnz(w) < 100, return; end
    xw = x(w);  tw = t(w);
    try
        [pk, loc] = findpeaks(xw, tw, 'MinPeakProminence', 0.1*max(abs(xw)), ...
                              'MinPeakDistance', 0.3);
    catch
        return;
    end
    keep = pk > 0;  pk = pk(keep);  loc = loc(keep);
    n = numel(pk);
    if n < 5, return; end
    y  = log(pk(:));
    c  = polyfit(loc(:), y, 1);
    r2 = 1 - sum((y - polyval(c, loc(:))).^2) / sum((y - mean(y)).^2);
    Tp = diff(loc);
    f_osc = 1 / mean(Tp);
    if std(Tp) / mean(Tp) > 0.25, return; end   % unevenly spaced peaks: not one clean mode
    sigma = -c(1);
    if sigma > 0 && r2 >= 0.7
        wd   = 2*pi*f_osc;
        zeta = sigma / sqrt(sigma^2 + wd^2);
    end
end

function r = rocof_regress(t, f, cfg)
    idx = t >= cfg.t_step & t <= cfg.t_step + cfg.rocof_win & isfinite(f);
    if nnz(idx) < 5
        r = NaN;
    else
        p = polyfit(t(idx) - cfg.t_step, f(idx), 1);
        r = p(1);
    end
end

function [t, x, resampled] = ensure_uniform(t, x, allow, name)
    dt  = diff(t);
    resampled = false;
    if isempty(dt), error('%s has insufficient timestamps.', name); end
    dtm = median(dt);
    if ~isfinite(dtm) || dtm <= 0
        error('%s has invalid timestamps.', name);
    end
    tol = max(1e-10, 1e-3 * dtm);
    if max(abs(dt - dtm)) <= tol, return; end
    if ~allow
        error(['%s timestamps are not uniformly sampled (dt range %.3g-%.3g s). ' ...
               'Set cfg.auto_resample = true or log with a fixed step.'], ...
               name, min(dt), max(dt));
    end
    % Integer number of intervals so BOTH original endpoints are kept; the
    % new step may differ slightly from the median step. Interpolation cannot
    % recover information lost to coarse or irregular logging.
    nInt = round((t(end) - t(1)) / dtm);
    if nInt < 1, error('%s time span is too short to resample.', name); end
    tn = linspace(t(1), t(end), nInt + 1).';
    xn = interp1(t, x, tn, 'linear');
    if any(~isfinite(xn)), error('%s resampling produced invalid output.', name); end
    t = tn; x = xn;
    resampled = true;
end

function out = ternary(cond, a, b)
    if cond, out = a; else, out = b; end
end

function s = fmt_err(sim, ref, mode)
% mode 'pct': percent difference from the reference (needs a nonzero reference)
% mode 'abs': absolute difference in the row's own unit (Hz, s, % or ratio)
    if isnan(sim) || isnan(ref)
        s = 'N/A';
    elseif strcmp(mode, 'pct') && ref ~= 0
        s = sprintf('%.2f %%', abs(sim - ref) / abs(ref) * 100);
    else
        s = sprintf('%.4f', abs(sim - ref));
    end
end

function print_kpis(name, K)
    fprintf('\n============ KPI SUMMARY: %s ============\n', name);
    fprintf('Pre-step frequency baseline : %.6f Hz\n', K.f_base);
    fprintf('Pre-step power baseline     : %.6f\n',    K.P_base);
    fprintf('RoCoF (100-ms regression)   : %+.6f Hz/s (|.| = %.6f)\n', K.rocof_signed, K.rocof_abs);
    fprintf('Frequency nadir             : %.6f Hz at %.4f s\n', K.f_nadir, K.t_nadir);
    fprintf('Deviation from baseline     : %.6f Hz (max |dev| %.6f Hz)\n', K.f_dev_nadir, K.f_dev_maxabs);
    fprintf('Deviation from 60 Hz        : %.6f Hz\n', K.f_dev_nom);
    fprintf('Final-window frequency      : %.6f Hz\n', K.f_post);
    fprintf('Final-window freq. slope    : %+.6f Hz/s%s\n', K.f_final_slope, ...
            ternary(K.f_still_moving, '  <-- still moving, settling unreliable', ''));
    fprintf('Frequency settling time     : %.4f s (reported)  |  %.4f s (provisional, algorithmic)\n', ...
            K.tset_f, K.tset_f_prov);
    fprintf('Final-window power          : %.6f%s\n', K.P_post, ...
            ternary(K.P_still_moving, '  (PROVISIONAL: power still trending)', ''));
    fprintf('Final-window power slope    : %+.6f /s\n', K.P_final_slope);
    fprintf('Net power change            : %+.6f\n',   K.dP);
    fprintf('Power peak                  : %.6f at %.4f s\n', K.P_peak, K.t_peak_P);
    fprintf('Power overshoot (whole rec.): %.3f %% provisional | reported: %.3f %%\n', K.overshoot, K.overshoot_reported);
    fprintf('Power overshoot (early win.): %.3f %% provisional | reported: %.3f %%\n', K.overshoot_early, K.overshoot_early_reported);
    fprintf('Power settling time         : %.4f s (reported)  |  %.4f s (provisional, algorithmic)\n', ...
            K.tset_P, K.tset_P_prov);
    if isnan(K.zeta)
        fprintf('Damping ratio               : not estimated (%d usable peaks, f_osc = %.3f Hz)\n', ...
                K.n_peaks, K.f_osc);
    else
        fprintf('Damping ratio (indicative)  : %.4f from %d peaks (f_osc = %.3f Hz)\n', ...
                K.zeta, K.n_peaks, K.f_osc);
    end
end