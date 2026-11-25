# Multi-Domain Transient & Grid-Forming Control Benchmark on the WSCC 9-Bus System

[![Platform](https://img.shields.io/badge/MATLAB%20%2F%20Simulink-EMT%20%26%20Phasor-0076A8?logo=mathworks&logoColor=white)](https://www.mathworks.com/)
[![Test System](https://img.shields.io/badge/Benchmark-WSCC%209--Bus%20(60%20Hz)-2E7D32)](#system-architecture--models)
[![Solver](https://img.shields.io/badge/Fixed--Step%20ode4-50%20%C2%B5s%20%2F%2025%20%C2%B5s-6A1B9A)](#reproducibility--quick-start)
[![Data](https://img.shields.io/badge/Results-S1--S4%20%2B%2032--Point%20(H%2CD)%20Sweep-E65100)](#benchmark-results)

A reproducible multi-domain electromagnetic transient (EMT) and phasor-domain benchmark comparing **Grid-Following (GFL)** and **Grid-Forming (GFM)** inverter topologies against a conventional synchronous-generator baseline on the standard **WSCC 9-bus** network. The suite evaluates four operating contingencies (`S1`–`S4`)—including weak-grid loss-of-synchronism verification across solver timesteps ($50\ \mu\text{s}$ vs. $25\ \mu\text{s}$)—and a **32-point decoupled $(H, D)$ sensitivity sweep**.

---

## Key Highlights

- **Four-Topology Benchmark:** Direct comparison of an All-SG phasor baseline (`Model 0`), Grid-Following PV (`Model 1`), RoCoF-Compensated Virtual Synchronous Generator (`Model 2`), and Synchronverter (`Model 3`) under identical disturbance protocols.
- **Weak-Grid Stability & Solver Validation (`S3`):** Under doubled line impedance ($2\times Z_{\text{line}}$) and a $+30\text{ MW}$ load step, `Model 1` (GFL PV) suffers loss of synchronism—independently verified at both $T_s = 50\ \mu\text{s}$ and $T_s = 25\ \mu\text{s}$ to rule out numerical instability—while both GFM topologies (`Model 2` and `Model 3`) ride through stably.
- **Superior Frequency & Surge Regulation (`S1`):** Relative to GFL PV, the RoCoF-VSG reduces 500 ms RoCoF by **18.4%** ($0.1399$ vs. $0.1715\text{ Hz/s}$) and cuts peak active-power surge by **55.0%** ($4.73$ vs. $10.50\text{ MW}$), while the Synchronverter achieves the fastest settling time across all four models (**14.50 s** vs. **19.60 s**).
- **Decoupled Inertia–Damping Mapping:** Full 32-point $(H, D_{\text{pu}})$ sweep with analytical and empirical damping ratios ($\zeta$) exported to structured CSVs for direct plotting and peer-review verification.

---

## System Architecture & Models

| Model | Topology | Simulation Domain | Base Power ($S_{\text{rated}}$) | Primary Control Role |
| :--- | :--- | :--- | :---: | :--- |
| **Model 0** | All-Synchronous Generators (Baseline) | Phasor | $100\text{ MVA}$ (Gen G1 base) | Reference electromechanical inertia & governor response |
| **Model 1** | Grid-Following (GFL) PV Inverter | Hybrid EMT / Phasor | $11\text{ MVA}$ at PCC | PLL-synchronized current-controlled PQ injection |
| **Model 2** | RoCoF-Compensated VSG (GFM) | Hybrid EMT / Phasor | $11\text{ MVA}$ ($100\text{ MVA}$ in `S4`) | Virtual swing equation + RoCoF feedforward + inner LCL double-loop |
| **Model 3** | Synchronverter (GFM) | Hybrid EMT / Phasor | $11\text{ MVA}$ ($100\text{ MVA}$ in `S4`) | Direct synchronous-machine stator/rotor electromagnetic emulation |

---

## Visual Results

### 1. Multi-Scenario Performance Comparison (`S1`–`S4`)
![Multi-Scenario Benchmark Results](results/multi_scenario_benchmark.png)
*Cross-contingency comparison of frequency dynamics, power sharing, and transient margins across `Model 0`–`Model 3`.*

### 2. Weak-Grid Loss of Synchronism & Timestep Verification (`S3`, $2\times Z_{\text{line}}$)
![Weak-Grid Collapse and Timestep Verification](results/s3_weak_grid_collapse.png)
*Time-domain PCC frequency and active-power trajectories under weak-grid conditions. `Model 1` (GFL PV) collapses identically at $T_s = 50\ \mu\text{s}$ and $T_s = 25\ \mu\text{s}$, whereas `Model 2` (RoCoF-VSG) and `Model 3` (Synchronverter) maintain stable synchronization.*

### 3. Decoupled $(H, D)$ Parameter Sensitivity Sweep
![Decoupled H and D Sensitivity Sweep](results/decoupled_H_D_sensitivity.png)
*32-point parametric map isolating the independent impact of virtual inertia constant $H$ and damping coefficient $D_{\text{pu}}$ on RoCoF, frequency nadir, settling time, and damping ratio $\zeta$.*

---

## Benchmark Results

### Baseline Contingency `S1` (+30 MW Load Step at $t = 50\text{ s}$)

| Model | $f_{\text{pre}}$ (Hz) | $\text{RoCoF}_{500\text{ms}}$ (Hz/s) | $f_{\text{nadir}}$ (Hz) | $\lvert \Delta f_{\max} \rvert$ (Hz) | $t_{s,f}$ (s) | $\Delta P_{\text{peak}}$ (MW) | $\Delta P / S_{\text{rated}}$ (%) |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **Model 0 (All-SG)** | 59.9976 | 0.1151 | 59.7835 | 0.2141 | 17.48 | 9.87 | 9.87 |
| **Model 1 (GFL PV)** | 60.0187 | 0.1715 | 59.7076 | 0.3111 | 19.60 | 10.50 | 95.44 |
| **Model 2 (RoCoF-VSG)** | 59.9990 | **0.1399** | 59.6778 | 0.3212 | 15.08 | **4.73** | **43.01** |
| **Model 3 (Synchronverter)** | 60.0486 | 0.1605 | **59.7661** | **0.2825** | **14.50** | 7.54 | 68.59 |

> *Bold values indicate the best-performing inverter-interfaced topology (`Models 1–3`) per metric. Full `S1`–`S4` metrics—including stability status and damping ratio (`Damping_zeta`)—are stored in [`results/reviewer_fixed_all_scenarios.csv`](results/reviewer_fixed_all_scenarios.csv), and the 32-point sweep dataset is stored in [`results/decoupled_H_D_sensitivity.csv`](results/decoupled_H_D_sensitivity.csv).*

### KPI Definitions
- **Normalized Power Surge ($\Delta P_{\text{peak}} / S_{\text{rated}}$):** Evaluated on each unit's respective base ($100\text{ MVA}$ for `Model 0` and `S4`; $11\text{ MVA}$ for inverter PCCs in `S1`–`S3`).
- **Frequency Settling Time ($t_{s,f}$):** Elapsed time after the $t = 50\text{ s}$ disturbance for PCC frequency to enter and remain strictly within $\pm 0.02\text{ Hz}$ of its post-disturbance steady state $f_{\text{ss}}$.
- **Step Overshoot ($PO_{P,\text{step}}$) & Damping Ratio ($\zeta$):** Overshoot is evaluated only when $\vert{}\Delta P_{\text{ss}}\vert{} \ge 0.05\,S_{\text{rated}}$; cases with near-zero steady-state inverter power shift or loss of synchronism are reported as `NaN` to prevent ill-conditioned division.

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
| | Damping & Power Filtering | $R_d = \dfrac{1}{3\omega_{\text{res}} C_f}$, $\quad \omega_{c,\text{lp}} = 2\pi(20)\text{ rad/s}$ |

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
├── models/                                     # Simulink (.slx) models & parameter (.mat) files
├── results/
│   ├── reviewer_fixed_all_scenarios.csv        # Complete S1–S4 KPIs & damping ratios
│   ├── decoupled_H_D_sensitivity.csv           # 32-point decoupled (H, D) sweep data
│   ├── multi_scenario_benchmark.png            # Cross-scenario comparative figure (300 DPI)
│   ├── s3_weak_grid_collapse.png               # Weak-grid collapse & 50/25 us verification (300 DPI)
│   └── decoupled_H_D_sensitivity.png           # Parametric (H, D) sensitivity map (300 DPI)
└── README.md
```

---

## Reproducibility & Quick Start

### Prerequisites
- **MATLAB & Simulink** (with Simscape Electrical / Specialized Power Systems for re-running `.slx` models; base MATLAB is sufficient to inspect all published tables via `demo_all.m`).

### Reproduce Summary Tables
Clone the repository and run `demo_all` in the MATLAB Command Window:

```matlab
git clone [https://github.com/Rajubahardar/BE---Final-year-project.git](https://github.com/Rajubahardar/BE---Final-year-project.git)
cd('BE---Final-year-project');
demo_all
```

This loads the verified benchmark datasets under `results/` and prints the full `S1`–`S4` contingency tables alongside the 32-point `(H, D)` sensitivity sweep without requiring re-simulation.

---

## Citation

If you use these models, controller gains, or benchmark datasets in academic work, please cite this repository:

```bibtex
@misc{bahardar2026wscc9gfm,
  author       = {Bahardar, Raju},
  title        = {Multi-Domain Transient and Grid-Forming Control Benchmark on the WSCC 9-Bus System},
  year         = {2026},
  howpublished = {\url{[https://github.com/Rajubahardar/BE---Final-year-project](https://github.com/Rajubahardar/BE---Final-year-project)}},
  note         = {MATLAB/Simulink EMT and Phasor Benchmark Suite}
}
```