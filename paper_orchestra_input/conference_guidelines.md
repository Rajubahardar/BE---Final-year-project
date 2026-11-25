# Conference Formatting & Authoring Guidelines (`IEEEtran`)

## 1. Venue Format & Page Budget
- **Target Template:** Standard IEEE double-column conference format (`\documentclass[conference]{IEEEtran}`, 10 pt font, US Letter paper).
- **Page Limit:** 6 to 8 pages for the main technical body (inclusive of all figures and tables), excluding the bibliography (`references.bib`).
- **Target Length:** Approximately 4,500 to 5,500 words across all sections, written in dense, objective IEEE power-engineering prose.

## 2. Mandatory Section Skeleton
Preserve the exact `\section{...}` commands and `\label{sec:...}` anchors defined in `template.tex`:
1. **Abstract & IEEE Keywords:** Single concise paragraph (150–220 words) summarizing the multi-domain WSCC 9-bus benchmark problem, the four evaluated topologies (`Model 0`–`Model 3`), key quantitative gains (`41.7%` peak frequency deviation reduction and `42.8%` faster settling in `S4`, IEEE 519 compliance $\text{THD}_v \le 1.13\%$), and decoupled $(H, D_{\text{pu}})$ design insights, followed by 4–6 IEEE index terms.
2. **Section I — Introduction (`\label{sec:intro}`):** Motivate the loss of rotational inertia and short-circuit strength in inverter-dominated grids, contrast grid-following (GFL) PLL instability against grid-forming (GFM) control on multi-machine networks, and enumerate 3–4 concrete contributions grounded strictly in `experimental_log.md`.
3. **Section II — Related Work (`\label{sec:related}`):** Organize prior literature into thematic clusters: (a) GFL inverter synchronization instability under low short-circuit ratio (SCR) weak grids, (b) Virtual Synchronous Generator (VSG) and derivative RoCoF feedforward control, (c) electromechanical Synchronverter architectures, and (d) multi-domain EMT/phasor co-simulation benchmarks and grid-forming standards (e.g., IEEE Std 2800, IEEE Std 519).
4. **Section III — Multi-Domain WSCC 9-Bus System and Control Formulations (`\label{sec:methodology}`):** Formalize the hybrid EMT/phasor test network ($60\ \text{Hz}$, fixed-step `ode4` at $T_s = 50\ \mu\text{s}$ and $25\ \mu\text{s}$), present the exact mathematical equations and tuned parameters ($H = 5.0\ \text{s}$, $D_{\text{pu}} = 80\ \text{p.u.}$) for `Model 1` (GFL PV), `Model 2` (RoCoF-VSG), and `Model 3` (Synchronverter), and define contingencies `S1`–`S4`.
5. **Section IV — Cross-Scenario Transient and Power-Quality Evaluation (`\label{sec:experiments}`):** Present the full 10-KPI comparison table across `S1`–`S4`, analyze `Model 1` loss of synchronism in `S3` ($\Delta f_{\max} = 12.98\ \text{Hz}$, $283.6\ \text{MW}$ surge) and `S4` ($533.9\ \text{MW}$ surge), quantify GFM transient improvements over `Model 0`, and verify harmonic compliance.
6. **Section V — Decoupled $(H, D)$ Parametric Sensitivity Analysis (`\label{sec:sensitivity}`):** Analyze the 32-point parametric sweep showing how virtual inertia $H$ governs initial $500\ \text{ms}$ RoCoF arrest independently from damping $D_{\text{pu}}$, which governs modal damping ratio $\zeta$ and settling time $t_{s,f}$.
7. **Section VI — Conclusion (`\label{sec:conclusion}`):** Synthesize key empirical takeaways and provide practical tuning and topology selection guidelines for weak-grid and high-penetration renewable integration.

## 3. Tables, Figures & Equations
- **Tables:** Use `booktabs` (`\toprule`, `\midrule`, `\bottomrule`) with `table*` (two-column span) for the wide 10-KPI cross-scenario table. Transcribe all numeric values verbatim from `experimental_log.md`. Display `NaN` entries for `Model 1` under `S3` and `S4` as `--` (or `Unstable`) with an explicit table footnote explaining post-disturbance loss of synchronism.
- **Figures (`figures/` directory):** Integrate and reference all provided visual assets before Section VI:
  - `finalmodel2_top.png` (or `.pdf`) and `finalmodel2_controller.png`: Single-column (`figure`) or two-column (`figure*`) system and cascaded inner-loop block diagrams in Section III.
  - `all_10_kpis_comparison.png`, `multi_scenario_benchmark.png`, and `s3_weak_grid_collapse.png`: Two-column (`figure*`) empirical comparison plots in Section IV.
  - `decoupled_H_D_sensitivity.png`: Two-column (`figure*`) sensitivity map in Section V.
- **Captions:** Write informative plain-text captions without manual `"Figure X:"` or `"Table Y:"` prefixes (handled automatically by LaTeX).

## 4. Scientific Integrity & Negative Constraints
- **Simulation Scope Only:** All experiments were conducted via offline multi-domain EMT/phasor simulation in MATLAB/Simulink (`ode4` solver). Do not claim hardware-in-the-loop (HIL) testing, physical inverter prototypes, or field measurements.
- **No Fabricated Data:** Do not extrapolate untested contingencies, invent additional baselines, or alter any numeric values from `experimental_log.md`.
- **Citation Discipline:** Use numeric IEEE citations (`\cite{...}`) matched strictly to keys in `references.bib`.