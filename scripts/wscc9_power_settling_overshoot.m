function A = wscc9_power_settling_overshoot(t,P,cfg)
% Power settling and overshoot analysis using a 2-second moving average.
% This function does not run Simulink and does not modify its inputs.

t = double(t(:));
P = double(P(:));
if numel(t) ~= numel(P) || numel(t) < 10
    error('Power analysis requires equal-length time and power vectors.');
end
if any(diff(t) <= 0)
    error('Time vector must be strictly increasing.');
end

dt = median(diff(t));
fs = 1/dt;
winSec = 2.0;
winN = max(1,round(winSec*fs));
Pma = movmean(P,winN,'Endpoints','shrink');

idxPre = t >= cfg.pre_start & t < cfg.t_step-cfg.pre_guard & isfinite(Pma);
idxFin = t >= max(cfg.t_step,t(end)-cfg.final_win) & isfinite(Pma);
idxPost = t >= cfg.t_step & isfinite(Pma);
if nnz(idxPre)<10 || nnz(idxFin)<10 || nnz(idxPost)<10
    error('Insufficient samples in pre-step, final, or post-step window.');
end

A = struct();
A.window_seconds = winSec;
A.window_samples = winN;
A.time = t;
A.power_raw = P;
A.power_moving_average = Pma;
A.P_baseline = mean(Pma(idxPre));
A.P_final = mean(Pma(idxFin));
A.dP = A.P_final-A.P_baseline;
A.final_slope = polyfit(t(idxFin)-t(end),Pma(idxFin),1);
A.final_slope = A.final_slope(1);
A.band = cfg.band_P_frac*abs(A.dP);
A.settling_time = NaN;
A.overshoot_percent = NaN;
A.early_overshoot_percent = NaN;
A.P_peak = NaN;
A.t_peak = NaN;
A.trend_test_passed = false;
A.settling_status = 'UNAVAILABLE';
A.overshoot_status = 'UNAVAILABLE';

if abs(A.dP) <= cfg.min_dP
    warning('Net power change is too small; power settling/overshoot unavailable.');
else
    % Settling: remain inside the band around the smoothed final reference.
    tp = t(idxPost);
    xp = Pma(idxPost);
    outside = ~isfinite(xp) | abs(xp-A.P_final)>A.band;
    lastOutside = find(outside,1,'last');
    if isempty(lastOutside)
        A.settling_time = 0;
    elseif lastOutside < numel(tp)
        nextInside = lastOutside+1;
        if tp(end)-tp(nextInside) >= cfg.dwell_s
            A.settling_time = tp(nextInside)-cfg.t_step;
        end
    end

    % Overshoot relative to the smoothed final value, in the direction
    % of the net change. This is a stated analysis definition, not universal.
    postP = Pma(idxPost);
    postT = t(idxPost);
    [peakDeviation,kpk] = max(sign(A.dP).*(postP-A.P_final));
    A.t_peak = postT(kpk);
    A.P_peak = A.P_final + sign(A.dP)*peakDeviation;
    A.overshoot_percent = 100*max(0,max(sign(A.dP).*(postP-A.P_final)))/abs(A.dP);
    early = postT <= cfg.t_step+cfg.os_win;
    if any(early)
        A.early_overshoot_percent = 100*max(0,max(sign(A.dP).*(postP(early)-A.P_final)))/abs(A.dP);
    end

    A.trend_test_passed = abs(A.final_slope)*cfg.final_win <= 0.5*A.band;
    if isnan(A.settling_time)
        A.settling_status = 'NOT DEMONSTRABLY SETTLED';
    else
        A.settling_status = 'ESTIMATE: 2-second smoothed signal';
    end
    if A.trend_test_passed
        A.overshoot_status = 'SMOOTHED ESTIMATE';
    else
        A.overshoot_status = 'PROVISIONAL: final power still trends';
    end
end

fprintf('\\n============================================\\n');
fprintf(' POWER SETTLING / OVERSHOOT ANALYSIS\\n');
fprintf('============================================\\n');
fprintf('Moving-average window:       %.2f s (%d samples)\\n',winSec,winN);
fprintf('Smoothed power baseline:     %.6f pu\\n',A.P_baseline);
fprintf('Smoothed final reference:    %.6f pu\\n',A.P_final);
fprintf('Net power change:            %+.6f pu\\n',A.dP);
fprintf('Final-window power slope:    %+.8f pu/s\\n',A.final_slope);
fprintf('Settling band:               +/- %.6f pu\\n',A.band);
fprintf('Power settling time:         %.4f s after disturbance\\n',A.settling_time);
fprintf('Settling status:             %s\\n',A.settling_status);
fprintf('Smoothed power peak:         %.6f pu at %.4f s\\n',A.P_peak,A.t_peak);
fprintf('Whole-record overshoot:      %.4f %%\\n',A.overshoot_percent);
fprintf('Early-window overshoot:      %.4f %%\\n',A.early_overshoot_percent);
fprintf('Overshoot status:            %s\\n',A.overshoot_status);
fprintf('============================================\\n');

end
