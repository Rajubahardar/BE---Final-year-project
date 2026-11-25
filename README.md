# Multi-Domain Transient & Grid-Forming Control Benchmark on the WSCC 9-Bus System

Publication benchmark comparing **Model 0 (All-SG Phasor Baseline)**, **Model 1 (Grid-Following PV EMT)**, **Model 2 (RoCoF-Compensated VSG EMT)**, and **Model 3 (Synchronverter EMT)** across four contingencies (`S1`–`S4`) and a 32-point decoupled `(H, D)` parameter sensitivity sweep.

## 1. Rated Power Base ($S_{\text{rated}}$) & KPI Definitions
- **Model 0 (All-SG Baseline):** Phasor-domain WSCC 9-bus system; $S_{\text{rated}} = 100\text{ MVA}$ (Generator G1 base) for normalized active power surge $\Delta P_{\text{peak}} / S_{\text{rated}}$.
- **Models 1, 2, and 3 (EMT Inverter-Interfaced):** Hybrid EMT/Phasor system with $S_{\text{rated}} = 11\text{ MVA}$ at the inverter PCC (and $S_{\text{rated}} = 100\text{ MVA}$ in High-RES Scenario `S4`).
- **Frequency Settling Time ($t_{s,f}$):** Time after the $t = 50\text{ s}$ disturbance required for PCC frequency to enter and remain within $\pm 0.02\text{ Hz}$ of post-disturbance steady-state $f_{\text{ss}}$.
- **Step Overshoot ($PO_{P,\text{step}}$):** Computed only when $|\Delta P_{\text{ss}}| \ge 0.05\,S_{\text{rated}}$; reported as `NaN` when net steady-state inverter power change is near zero or the system is unstable.

## 2. Controller Equations & Tuned Gains
### Model 2: RoCoF-Compensated Virtual Synchronous Generator (VSG)
$$2H\,\frac{d\Delta\omega}{dt} = P_{\text{set}} - P_e - D_p\,\Delta\omega - K_{\text{RoCoF}}\,\frac{df_{\text{PCC}}}{dt}$$
- **Swing & Droop Parameters:** $H = 5.0\text{ s}$ ($J = \frac{2 H S_{\text{rated}}}{\omega_n^2}$), $D_{\text{pu}} = 80\text{ p.u.}$ ($D_p = \frac{D_{\text{pu}} S_{\text{rated}}}{\omega_n^2}$), $D_q = \frac{S_{\text{rated}}}{0.05\,V_{n,\text{peak}}}$, $K_q = \frac{0.05\,V_{n,\text{peak}}}{S_{\text{rated}}}$.
- **Inner Double-Loop LCL Gains ($11\text{ MVA}$ base):** $\omega_{ci} = 2\pi(500)\text{ rad/s}$, $\omega_{cv} = \omega_{ci}/5$, $K_{ip} = \omega_{ci} L_s$, $K_{vp} = \omega_{cv} C_f$, $K_{vi} = K_{vp}(\omega_{cv}/4)$, active damping $R_d = \frac{1}{3\omega_{\text{res}} C_f}$, low-pass cutoff $\omega_{c,\text{lp}} = 2\pi(20)\text{ rad/s}$.

### Model 3: Synchronverter
$$J\,\frac{d\omega}{dt} = T_m - T_e - D_p(\omega - \omega_n), \quad T_e = M_f i_f \langle i_g, \widetilde{\sin}\theta \rangle, \quad e = \omega M_f i_f \widetilde{\sin}\theta$$
$$K_v\,\frac{d(M_f i_f)}{dt} = Q_{\text{set}} - Q + D_q(V_{n,\text{peak}} - |V_g|), \quad Q = -\omega M_f i_f \langle i_g, \widetilde{\cos}\theta \rangle$$
- **Synchronverter Gains ($11\text{ MVA}$ base):** $J = \frac{2 H S_{\text{rated}}}{\omega_n^2} = 154.81\text{ kg}\cdot\text{m}^2$, $D_p = \frac{D_{\text{pu}} S_{\text{rated}}}{\omega_n^2} = 6192.4\text{ N}\cdot\text{m}\cdot\text{s}$, $D_q = \frac{S_{\text{rated}}}{0.05\,V_{n,\text{peak}}} = 6.736\times 10^5\text{ VAr/V}$, $\tau_v = 0.02\text{ s}$ ($K_v = \tau_v \omega_n D_q$).

## 3. Baseline S1 (+30 MW Load Step) KPIs

| Model | f_pre (Hz) | RoCoF 500ms (Hz/s) | f_nadir (Hz) | |df_max| (Hz) | ts_f (s) | dP_peak (MW) | dP/S_rated (%) |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| Model 0 (All-SG) | 59.9976 | 0.1151 | 59.7835 | 0.2141 | 17.48 | 9.87 | 9.87 |
| Model 1 (GFL PV) | 60.0187 | 0.1715 | 59.7076 | 0.3111 | 19.60 | 10.50 | 95.44 |
| Model 2 (RoCoF-VSG) | 59.9990 | 0.1399 | 59.6778 | 0.3212 | 15.08 | 4.73 | 43.01 |
| Model 3 (Synchronverter) | 60.0486 | 0.1605 | 59.7661 | 0.2825 | 14.50 | 7.54 | 68.59 |

## 4. Quick Start
- Run `demo_all` in MATLAB to print all `S1`–`S4` contingency tables and 32-point `(H, D)` sensitivity sweep tables.
- Figures in `results/`: `multi_scenario_benchmark.png` and `decoupled_H_D_sensitivity.png`.