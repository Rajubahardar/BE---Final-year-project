%% plot_all_10_kpis.m
% Publication-grade 2x5 comparison of all 10 KPIs from reviewer_fixed_all_scenarios.csv.
% Scales Y-axes to stable operating ranges and annotates exact CSV values on clipped outliers.

csvPath = fullfile('results', 'reviewer_fixed_all_scenarios.csv');
assert(isfile(csvPath), 'CSV file not found: %s', csvPath);

T = readtable(csvPath, 'TextType', 'string');

scenarios = unique(T.Scenario, 'stable');
models    = unique(T.Model, 'stable');

scenLabels = cell(numel(scenarios), 1);
for s = 1:numel(scenarios)
    parts = split(scenarios(s), '_');
    scenLabels{s} = char(parts(1));
end
modelLabels = cellstr(models);

kpiMap = {
    'RoCoF_500ms_Hz_s', '1. RoCoF (500 ms)',          'Hz/s';
    'Delta_f_max_Hz',   '2. Max Freq. Dev. |\Deltaf|', 'Hz';
    'ts_f_s',           '3. Freq. Settling t_{s,f}',   's';
    'Damping_zeta',     '4. Damping Ratio \zeta',      'Ratio';
    'ts_P_s',           '5. Power Settling t_{s,P}',   's';
    'dP_surge_pu_pct',  '6. Power Surge \DeltaP',      '% S_{rated}';
    'PO_P_step_pct',    '7. Power Overshoot PO_P',     '%';
    'dV_PCC_max_pct',   '8. PCC Voltage Dev. \DeltaV', '%';
    'THDv_pct',         '9. Voltage THD_v',            '%';
    'THDi_pct',         '10. Current THD_i',           '%';
};

colors = [
    0.12 0.47 0.71;  % Model 0 (All-SG)
    0.84 0.15 0.16;  % Model 1 (GFL PV)
    0.93 0.69 0.13;  % Model 2 (RoCoF-VSG)
    0.17 0.63 0.17;  % Model 3 (Synchronverter)
];

fig = figure('Color', 'w', 'Units', 'pixels', 'Position', [40 40 1900 880]);
tl = tiledlayout(2, 5, 'TileSpacing', 'compact', 'Padding', 'normal');
title(tl, 'All 10 Benchmark KPIs Across Scenarios S1–S4 (Outlier Collapse Values Labeled at Top)', ...
    'FontSize', 14, 'FontWeight', 'bold');

for k = 1:size(kpiMap, 1)
    colName  = kpiMap{k, 1};
    kpiTitle = kpiMap{k, 2};
    yUnit    = kpiMap{k, 3};

    Y = nan(numel(scenarios), numel(models));
    isStable = false(numel(scenarios), numel(models));

    for s = 1:numel(scenarios)
        for m = 1:numel(models)
            idx = find((T.Scenario == scenarios(s)) & (T.Model == models(m)), 1);
            if ~isempty(idx)
                Y(s, m) = T.(colName)(idx);
                isStable(s, m) = (T.Status(idx) == "Stable");
            end
        end
    end

    % Omit models with no non-zero finite measurements in this KPI (e.g., Phasor THD/dV)
    activeM = find(any(isfinite(Y) & Y ~= 0, 1));
    if isempty(activeM)
        activeM = 1:numel(models);
    end

    Y_sub = Y(:, activeM);
    st_sub = isStable(:, activeM);

    % Compute Y-axis cap from stable runs so stable bars are never crushed
    stableVals = Y_sub(st_sub & isfinite(Y_sub));
    if ~isempty(stableVals)
        yCap = max(stableVals) * 1.25;
    else
        yCap = max(Y_sub(:), [], 'omitnan') * 1.15;
    end
    if ~isfinite(yCap) || yCap <= 0
        yCap = 1;
    end

    Y_plot = min(Y_sub, yCap);

    ax = nexttile;
    b = bar(Y_plot, 'grouped', 'BarWidth', 0.82);
    for idxM = 1:numel(activeM)
        b(idxM).FaceColor = colors(activeM(idxM), :);
        b(idxM).EdgeColor = 'none';
    end

    grid on;
    box on;
    ax.XTick = 1:numel(scenarios);
    ax.XTickLabel = scenLabels;
    ax.FontSize = 9.5;
    ylim([0, yCap * 1.12]);
    title(kpiTitle, 'FontSize', 10.5, 'FontWeight', 'bold');
    ylabel(yUnit, 'FontSize', 9.5);

    % Annotate exact CSV values on top of any clipped outlier bars
    for s = 1:numel(scenarios)
        for idxM = 1:numel(activeM)
            rawVal = Y_sub(s, idxM);
            if isfinite(rawVal) && rawVal > yCap
                if isprop(b(idxM), 'XEndPoints')
                    xPos = b(idxM).XEndPoints(s);
                else
                    xPos = s + b(idxM).XOffset;
                end
                if rawVal >= 100
                    lblStr = sprintf('%.0f', rawVal);
                else
                    lblStr = sprintf('%.2f', rawVal);
                end
                text(xPos, yCap * 1.02, lblStr, ...
                    'Color', [0.75 0 0], 'FontWeight', 'bold', ...
                    'FontSize', 8.5, 'HorizontalAlignment', 'center', ...
                    'VerticalAlignment', 'bottom');
            end
        end
    end
end

% Global legend preserving all 4 models regardless of subplot filtering
hold(ax, 'on');
legHandles = gobjects(1, numel(models));
for m = 1:numel(models)
    legHandles(m) = patch(ax, NaN, NaN, colors(m, :), 'EdgeColor', 'none');
end
lgd = legend(legHandles, modelLabels, 'Orientation', 'horizontal', 'FontSize', 10.5);
lgd.Layout.Tile = 'south';

outPath = fullfile('results', 'all_10_kpis_comparison.png');
if exist('exportgraphics', 'file')
    exportgraphics(fig, outPath, 'Resolution', 300);
else
    print(fig, outPath, '-dpng', '-r300');
end
fprintf('Saved improved 10-KPI comparison figure to %s\n', outPath);