# Multi-Domain Transient & Grid-Forming Control Benchmark on the WSCC 9-Bus System

[![Platform](https://img.shields.io/badge/MATLAB%20%2F%20Simulink-EMT%20%26%20Phasor-0076A8?logo=mathworks&logoColor=white)](https://www.mathworks.com/)
[![Test System](https://img.shields.io/badge/Benchmark-WSCC%209--Bus%20(60%20Hz)-2E7D32)](#system-architecture--models)
[![Solver](https://img.shields.io/badge/Fixed--Step%20ode4-50%20%C2%B5s%20%2F%2025%20%C2%B5s-6A1B9A)](#reproducibility--quick-start)
[![Data](https://img.shields.io/badge/Results-S1--S4%20%2B%2032--Point%20(H%2CD)%20Sweep-E65100)](#benchmark-results-s1s4)

A reproducible multi-domain electromagnetic transient (EMT) and phasor-domain benchmark comparing **Grid-Following (GFL)** and **Grid-Forming (GFM)** inverter topologies against a conventional synchronous-generator baseline on the standard **WSCC 9-bus** network. The suite evaluates four operating contingencies (`S1`–`S4`)—including weak-grid loss-of-synchronism verification across solver timesteps ($50\ \mu\text{s}$ vs. $25\ \mu\text{s}$)—and a **32-point decoupled $(H, D)$ sensitivity sweep**.

---

## Key Highlights

- **Grid-Forming Stability Across All Contingencies (`S1`–`S4`):** While `Model 1` (GFL PV) loses synchronism in both the weak-grid (`S3`: $\Delta f_{\max} = 12.98\text{ Hz}$, $283.6\text{ MW}$ surge) and high-RES (`S4`: frequency collapse to $33.04\text{ Hz}$, $533.9\text{ MW}$ surge) scenarios, both GFM topologies (`Model 2` RoCoF-VSG and `Model 3` Synchronverter) remain stable across all four contingencies.
- **High-RES Frequency Regulation (`S4`, $100\text{ MVA}$ Base):** At high renewable penetration, `Model 2` (RoCoF-VSG) outperforms the conventional `Model 0` (All-SG) baseline—cutting maximum frequency deviation by **41.7%** ($0.1248$ vs. $0.2141\text{ Hz}$) and settling **42.8% faster** ($9.99$ vs. $17.48\text{ s}$) with $\zeta = 0.3621$.
- **Baseline Load-Step & Load-Shed Performance (`S1`, `S2`):** In `S1`, `Model 2` reduces 500 ms RoCoF by **18.5%** ($0.1399$ vs. $0.1715\text{ Hz/s}$) and peak power surge by **54.9%** ($4.73$ vs. $10.50\text{ MW}$) relative to `Model 1`, while `Model 3` achieves the fastest settling time in both `S1` (**14.50 s**) and `S2` (**19.08 s**).
- **Power Quality Compliance:** Across all four scenarios, both GFM EMT models remain well within IEEE 519 harmonic limits ($\text{THD}_v \le 1.13\%$, $\text{THD}_i \le 0.85\%$).

---

## System Architecture & Models

| Model | Topology | Simulation Domain | Base Power ($S_{\text{rated}}$) | Primary Control Role |
| :--- | :--- | :--- | :---: | :--- |
| **Model 0** | All-Synchronous Generators (Baseline) | Phasor | $100\text{ MVA}$ (Gen G1 base) | Reference electromechanical inertia & governor response |
| **Model 1** | Grid-Following (GFL) PV Inverter | Hybrid EMT / Phasor | $11\text{ MVA}$ ($100\text{ MVA}$ in `S4`) | PLL-synchronized current-controlled PQ injection |
| **Model 2** | RoCoF-Compensated VSG (GFM) | Hybrid EMT / Phasor | $11\text{ MVA}$ ($100\text{ MVA}$ in `S4`) | Virtual swing equation + RoCoF feedforward + inner LCL double-loop |
| **Model 3** | Synchronverter (GFM) | Hybrid EMT / Phasor | $11\text{ MVA}$ ($100\text{ MVA}$ in `S4`) | Direct synchronous-machine stator/rotor electromagnetic emulation |

---

## Contingency Scenarios (`S1`–`S4`)

| Scenario ID | Disturbance Event ($t = 50\text{ s}$) | Network / Rating Condition | Primary Stress Tested |
| :--- | :--- | :--- | :--- |
| **`S1_LoadStep_30MW`** | $+30\text{ MW}$ load step | Nominal grid, $S_{\text{rated}} = 11\text{ MVA}$ (inverters) | Baseline inertial arrest, nadir, and active-power surge |
| **`S2_LoadShed_45MW`** | $-45\text{ MW}$ load shedding | Nominal grid, $S_{\text{rated}} = 11\text{ MVA}$ (inverters) | Over-frequency arrest, reverse power absorption, voltage rise |
| **`S3_WeakGrid_30MW`** | $+30\text{ MW}$ load step | Weak grid ($2\times Z_{\text{line}}$), $S_{\text{rated}} = 11\text{ MVA}$ | Low-SCR synchronization stability ($50\ \mu\text{s}$ vs. $25\ \mu\text{s}$ verified) |
| **`S4_HighRES_100MVA`** | $+30\text{ MW}$ load step | High-RES scale, $S_{\text{rated}} = 100\text{ MVA}$ (inverters) | High-penetration frequency support and large-signal stability |

---

## Visual Results

### 1. Multi-Scenario Performance Comparison (`S1`–`S4`)
![Multi-Scenario Benchmark Results](results/multi_scenario_benchmark.png)
*Cross-contingency comparison of frequency dynamics, active-power surge, and transient margins across `Model 0`–`Model 3`.*

### 2. Weak-Grid Loss of Synchronism & Timestep Verification (`S3`, $2\times Z_{\text{line}}$)
![Weak-Grid Collapse and Timestep Verification](results/s3_weak_grid_collapse.png)
*Time-domain PCC frequency and active-power trajectories under weak-grid conditions. `Model 1` (GFL PV) collapses identically at $T_s = 50\ \mu\text{s}$ and $T_s = 25\ \mu\text{s}$, whereas `Model 2` (RoCoF-VSG) and `Model 3` (Synchronverter) maintain stable synchronization.*

### 3. Decoupled $(H, D)$ Parameter Sensitivity Sweep
![Decoupled H and D Sensitivity Sweep](results/decoupled_H_D_sensitivity.png)
*32-point parametric map isolating the independent impact of virtual inertia constant $H$ and damping coefficient $D_{\text{pu}}$ on RoCoF, frequency nadir, settling time, and damping ratio $\zeta$.*

### 4. All 10 Benchmark KPIs Across Scenarios (`S1`–`S4`)
![All 10 Benchmark KPIs Comparison](results/all_10_kpis_comparison.png)
*Grouped comparison of all 10 benchmark KPIs across `S1`–`S4`. Clipped red bars indicate `Model 1 (GFL PV)` loss of synchronism in `S3` and `S4` with exact CSV collapse values labeled above each bar.*

---

## Benchmark Results (`S1`–`S4`)

Full 10-KPI contingency metrics exported directly from [`results/reviewer_fixed_all_scenarios.csv`](results/reviewer_fixed_all_scenarios.csv):

| Scenario | Model | Status | 1. $\text{RoCoF}_{500\text{ms}}$ (Hz/s) | 2. $\lvert\Delta f_{\max}\rvert$ (Hz) | 3. $t_{s,f}$ (s) | 4. $\zeta$ | 5. $t_{s,P}$ (s) | 6. $\Delta P / S_{\text{rated}}$ (%) | 7. $PO_{P,\text{step}}$ (%) | 8. $\Delta V_{\text{PCC,max}}$ (%) | 9. $\text{THD}_v$ (%) | 10. $\text{THD}_i$ (%) |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **`S1`** (+30 MW) | Model 0 (All-SG) | Stable | 0.1151 | 0.2141 | 17.48 | 1.0000 | 14.62 | 9.87 | 95.96 | `NaN` | 0.00 | 0.00 |
| | Model 1 (GFL PV) | Stable | 0.1715 | 0.3111 | 19.60 | 0.2620 | 25.00 | 95.44 | 42.62 | `NaN` | `NaN` | `NaN` |
| | Model 2 (RoCoF-VSG) | Stable | **0.1399** | 0.3212 | 15.08 | 0.0526 | 25.00 | **43.01** | 84.74 | **5.61** | **0.20** | **0.23** |
| | Model 3 (Synchronverter) | Stable | 0.1605 | **0.2825** | **14.50** | 0.1296 | 25.00 | 68.59 | 66.33 | 9.92 | 0.30 | 0.33 |
| **`S2`** (-45 MW) | Model 0 (All-SG) | Stable | 0.1734 | 0.3191 | 18.96 | 1.0000 | 14.67 | 14.82 | 97.01 | `NaN` | 0.00 | 0.00 |
| | Model 1 (GFL PV) | Stable | 0.2146 | 0.4654 | 25.00 | 0.3550 | 25.00 | 130.10 | 30.33 | `NaN` | `NaN` | `NaN` |
| | Model 2 (RoCoF-VSG) | Stable | **0.1926** | 0.4871 | 25.00 | 0.0316 | 25.00 | **65.29** | 90.54 | 11.44 | **0.50** | **0.69** |
| | Model 3 (Synchronverter) | Stable | 0.2238 | **0.4238** | **19.08** | 0.1067 | 25.00 | 106.39 | 71.38 | **8.99** | 1.13 | 0.85 |
| **`S3`** (Weak Grid) | Model 0 (All-SG) | Stable | 0.0917 | 0.1983 | 17.76 | 1.0000 | 13.59 | 7.88 | `NaN` | `NaN` | 0.00 | 0.00 |
| | Model 1 (GFL PV) | **Unstable** | 10.0155 | 12.9780 | `NaN` | `NaN` | `NaN` | 2578.20 | `NaN` | `NaN` | `NaN` | `NaN` |
| | Model 2 (RoCoF-VSG) | Stable | **0.1197** | 0.4105 | 25.00 | 1.0000 | 25.00 | **55.36** | 150.41 | 11.72 | 0.45 | 0.42 |
| | Model 3 (Synchronverter) | Stable | 0.1662 | **0.3222** | 25.00 | 0.0286 | 25.00 | 79.04 | **91.41** | **8.90** | **0.04** | **0.05** |
| **`S4`** (High-RES) | Model 0 (All-SG) | Stable | 0.1151 | 0.2141 | 17.48 | 1.0000 | 14.62 | 9.87 | 95.96 | `NaN` | 0.00 | 0.00 |
| | Model 1 (GFL PV) | **Unstable** | 0.3108 | 26.7798 | `NaN` | `NaN` | `NaN` | 533.90 | `NaN` | `NaN` | `NaN` | `NaN` |
| | Model 2 (RoCoF-VSG) | Stable | 0.1693 | **0.1248** | **9.99** | 0.3621 | **18.78** | 17.13 | **29.52** | 12.84 | 0.34 | 0.38 |
| | Model 3 (Synchronverter) | Stable | **0.1603** | 0.2820 | 14.52 | 1.0000 | 25.00 | **7.51** | `NaN` | **9.85** | **0.21** | **0.24** |

> *Bold values indicate the best-performing stable inverter topology (`Models 1–3`) per metric within each scenario. Complete 16-column records (including pre-fault frequency $f_{\text{pre}}$, frequency extremum $f_{\text{ext}}$, and peak active-power deviation $\Delta P_{\text{peak}}$ in MW) are archived in [`results/reviewer_fixed_all_scenarios.csv`](results/reviewer_fixed_all_scenarios.csv); the 32-point parametric sweep is in [`results/decoupled_H_D_sensitivity.csv`](results/decoupled_H_D_sensitivity.csv).*

### KPI Definitions
- **Normalized Power Surge ($\Delta P_{\text{peak}} / S_{\text{rated}}$):** Evaluated on each unit's rated base ($100\text{ MVA}$ for `Model 0` and `S4`; $11\text{ MVA}$ for inverter PCCs in `S1`–`S3`).
- **Frequency & Active-Power Settling Times ($t_{s,f}$, $t_{s,P}$):** Elapsed time after the $t = 50\text{ s}$ disturbance for PCC frequency ($\pm 0.02\text{ Hz}$) and active power to enter and remain within their steady-state bands (capped at the $25.00\text{ s}$ post-disturbance observation window).
- **Step Overshoot ($PO_{P,\text{step}}$) & Damping Ratio ($\zeta$):** Overshoot is evaluated only when $\vert{}\Delta P_{\text{ss}}\vert{} \ge 0.05\,S_{\text{rated}}$; near-zero steady-state shifts and unstable loss-of-synchronism cases are reported as `NaN` to avoid ill-conditioned division.

---

## Controller Formulation & Tuned Gains

### Model 2 — RoCoF-Compensated Virtual Synchronous Generator (VSG)

$$2H\,\frac{d\Delta\omega}{dt} = P_{\text{set}} - P_e - D_p\,\Delta\omega - K_{\text{RoCoF}}\,\frac{df_{\text{PCC}}}{dt}$$

| Control Layer | Parameter / Gain | Formulation / Tuned Value ($11\text{ MVA}$ Base) |
| :--- | :--- | :--- |
| **Outer Swing & Droop** | Virtual Inertia ($H$, $J$) | $H = 5.0\text{ s}$, $\quad J = \dfrac{2 H S_{\text{rated}}}{\omega_n^2}$ |
| | Active Power Damping ($D_{\text{pu}}$, $D_p$) | $D_{\text{pu}} = 80\text{ p.u.}$, $\quad D_p = \dfrac{D_{\text{pu}} S_{\text{rated}}}{\omega_n^2}$ |
| | Reactive Power Droop ($D_q$, $K_q$) | $D_q = \dfrac{S_{\text{rated}}}{0.05\,V_{n,\text{peak}}}$, $\quad K_q = \dfrac{0.05\,V_{n,\text{peak}}}{S_{\text{rated}}}$ |
| **Inner Double-Loop LCL** | Current & Voltage Bandwidths | $\omega_{ci} = 2\pi(500)\text{ rad/s}$, $\quad \omega_{cv} = \omega_{ci} / 5$ |
| | Proportional–Integral Gains | $K_{ip} = \omega_{ci} L_s$, $\quad K_{vp} = \omega_{cv} C_f$, $\quad K_{vi} = K_{vp}(\omega_{cv}/4)$ |
| | Active Damping & Filtering | $R_d = \dfrac{1}{3\omega_{\text{res}} C_f}$, $\quad \omega_{c,\text{lp}} = 2\pi(20)\text{ rad/s}$ |

---

### Model 3 — Synchronverter

$$J\,\frac{d\omega}{dt} = T_m - T_e - D_p(\omega - \omega_n), \qquad T_e = M_f i_f \langle i_g, \widetilde{\sin}\theta \rangle, \qquad e = \omega M_f i_f \widetilde{\sin}\theta$$

$$K_v\,\frac{d(M_f i_f)}{dt} = Q_{\text{set}} - Q + D_q(V_{n,\text{peak}} - \vert{}V_g\vert{}), \qquad Q = -\omega M_f i_f \langle i_g, \widetilde{\cos}\theta \rangle$$

| Parameter | Expression | Value ($11\text{ MVA}$ Base) |
| :--- | :--- | :--- |
| Virtual Moment of Inertia ($J$) | $\dfrac{2 H S_{\text{rated}}}{\omega_n^2}$ | $154.81\text{ kg}\cdot\text{m}^2$ |
| Frequency Droop / Damping ($D_p$) | $\dfrac{D_{\text{pu}} S_{\text{rated}}}{\omega_n^2}$ | $6192.4\text{ N}\cdot\text{m}\cdot\text{s}$ |
| Voltage Droop Coefficient ($D_q$) | $\dfrac{S_{\text{rated}}}{0.05\,V_{n,\text{peak}}}$ | $6.736 \times 10^5\text{ VAr/V}$ |
| Voltage Loop Time Constant & Gain ($\tau_v$, $K_v$) | $K_v = \tau_v \omega_n D_q$ | $\tau_v = 0.02\text{ s}$ |

---

## Repository Structure

```text
BE---Final-year-project/
├── demo_all.m                                  # Prints formatted S1–S4 & 32-point (H, D) tables
├── plot_all_10_kpis.m                          # Generates 300-DPI 2x5 comparison of all 10 KPIs
├── models/                                     # Simulink (.slx) models & parameter (.mat) files
├── results/
│   ├── reviewer_fixed_all_scenarios.csv        # Complete S1–S4 KPIs, zeta & THD metrics
│   ├── decoupled_H_D_sensitivity.csv           # 32-point decoupled (H, D) sweep data
│   ├── multi_scenario_benchmark.png            # Cross-scenario comparative figure (300 DPI)
│   ├── s3_weak_grid_collapse.png               # Weak-grid collapse & 50/25 us verification (300 DPI)
│   ├── decoupled_H_D_sensitivity.png           # Parametric (H, D) sensitivity map (300 DPI)
│   └── all_10_kpis_comparison.png              # All 10 KPIs grouped comparison figure (300 DPI)
└── README.md
```

---

## Reproducibility & Quick Start

### Prerequisites
- **MATLAB & Simulink** (with Simscape Electrical / Specialized Power Systems to re-run `.slx` models; base MATLAB is sufficient to inspect all published tables via `demo_all.m` or regenerate `results/all_10_kpis_comparison.png` via `plot_all_10_kpis.m`).

### Reproduce Summary Tables & 10-KPI Figure
Clone the repository and run `demo_all` and `plot_all_10_kpis` in the MATLAB Command Window:

```matlab
git clone [https://github.com/Rajubahardar/BE---Final-year-project.git](https://github.com/Rajubahardar/BE---Final-year-project.git)
cd('BE---Final-year-project');
demo_all
plot_all_10_kpis
```

This reads the verified CSV datasets under `results/` and reproduces the summary tables and the 300-DPI 10-KPI comparison figure without re-running Simulink.

---

## Citation

If you use these models, controller parameters, or benchmark datasets in academic work, please cite this repository:

```bibtex
@misc{bahardar2026wscc9gfm,
  author       = {Bahardar, Raju},
  title        = {Multi-Domain Transient and Grid-Forming Control Benchmark on the WSCC 9-Bus System},
  year         = {2026},
  howpublished = {\url{[https://github.com/Rajubahardar/BE---Final-year-project](https://github.com/Rajubahardar/BE---Final-year-project)}},
  note         = {MATLAB/Simulink EMT and Phasor Benchmark Suite}
}
```