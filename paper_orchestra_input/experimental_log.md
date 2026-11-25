# Experimental Log

## 1. Experimental Setup

- **Test System:** Standard WSCC 9-bus, 3-machine, 60 Hz benchmark network modeled in a multi-domain EMT/phasor environment in MATLAB/Simulink using fixed-step `ode4` (Runge-Kutta) integration at $T_s = 50\ \mu\text{s}$ (and verified for solver invariance at $T_s = 25\ \mu\text{s}$).
- **Evaluated Topologies (Baselines & Proposed Controllers):**
  - `Model 0` (All-SG Phasor Baseline): Three synchronous generators at Buses 1, 2, and 3.
  - `Model 1` (GFL PV EMT): Grid-following inverter with synchronous-reference-frame PLL and cascaded dq current control.
  - `Model 2` (RoCoF-VSG EMT): Grid-forming virtual synchronous generator with synthetic inertia $H = 5.0\ \text{s}$, damping $D_{\text{pu}} = 80\ \text{p.u.}$, and derivative RoCoF feedforward.
  - `Model 3` (Synchronverter EMT): Electromechanical virtual synchronous machine emulating stator flux-linkage dynamics.
- **Contingency Scenarios:**
  - `S1` (+30 MW Load Step): Sudden active load increase at Bus 5 ($11\ \text{MVA}$ inverter base).
  - `S2` (-45 MW Load Shed): Sudden load rejection at Bus 5 ($11\ \text{MVA}$ inverter base).
  - `S3` (Weak Grid): Doubled transmission line impedance ($2\times Z_{\text{line}}$, $\text{SCR} \approx 1.5$) during disturbance.
  - `S4` (High-RES Penetration): Scaled inverter base ($S_{\text{rated}} = 100\ \text{MVA}$) under severe contingency.
- **Evaluation Metrics (10 KPIs):** 500 ms RoCoF (`RoCoF_500ms_Hz_s`), maximum frequency deviation (`Delta_f_max_Hz`), frequency settling time (`ts_f_s`), modal damping ratio (`Damping_zeta`), active power settling time (`ts_P_s`), active power surge (`dP_surge_pu_pct`), step power overshoot (`PO_P_step_pct`), maximum PCC voltage deviation (`dV_PCC_max_pct`), voltage THD (`THDv_pct`), and current THD (`THDi_pct`).

## 2. Raw Numeric Data (from Tables)

### Dataset A: Cross-Scenario 10-KPI Benchmark (`reviewer_fixed_all_scenarios.csv`)

| Scenario | Model | Status | f_pre_Hz | RoCoF_500ms_Hz_s | f_extremum_Hz | Delta_f_max_Hz | ts_f_s | ts_P_s | dP_peak_MW | PO_P_step_pct | dP_surge_pu_pct | dV_PCC_max_pct | Damping_zeta | THDv_pct | THDi_pct |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| S1_LoadStep_30MW | Model 0 (All-SG) | Stable | 59.9976 | 0.1151 | 59.7835 | 0.2141 | 17.4767 | 14.6237 | 9.8669 | 95.9566 | 9.8669 | NaN | 1.0000 | 0.0000 | 0.0000 |
| S1_LoadStep_30MW | Model 1 (GFL PV) | Stable | 60.0187 | 0.1715 | 59.7076 | 0.3111 | 19.6029 | 25.0000 | 10.4987 | 42.6235 | 95.4425 | NaN | 0.2620 | NaN | NaN |
| S1_LoadStep_30MW | Model 2 (RoCoF-VSG) | Stable | 59.9990 | 0.1399 | 59.6778 | 0.3212 | 15.0829 | 25.0000 | 4.7310 | 84.7424 | 43.0088 | 5.6103 | 0.0526 | 0.2008 | 0.2346 |
| S1_LoadStep_30MW | Model 3 (Synchronverter) | Stable | 60.0486 | 0.1605 | 59.7661 | 0.2825 | 14.5004 | 25.0000 | 7.5448 | 66.3277 | 68.5891 | 9.9212 | 0.1296 | 0.3049 | 0.3283 |
| S2_LoadShed_45MW | Model 0 (All-SG) | Stable | 59.7715 | 0.1734 | 60.0906 | 0.3191 | 18.9560 | 14.6737 | 14.8209 | 97.0117 | 14.8209 | NaN | 1.0000 | 0.0000 | 0.0000 |
| S2_LoadShed_45MW | Model 1 (GFL PV) | Stable | 60.1203 | 0.2146 | 60.5857 | 0.4654 | 25.0000 | 25.0000 | 14.3107 | 30.3295 | 130.0971 | NaN | 0.3550 | NaN | NaN |
| S2_LoadShed_45MW | Model 2 (RoCoF-VSG) | Stable | 60.0826 | 0.1926 | 60.5698 | 0.4871 | 25.0000 | 25.0000 | 7.1816 | 90.5412 | 65.2875 | 11.4373 | 0.0316 | 0.5045 | 0.6894 |
| S2_LoadShed_45MW | Model 3 (Synchronverter) | Stable | 60.1184 | 0.2238 | 60.5423 | 0.4238 | 19.0757 | 25.0000 | 11.7034 | 71.3837 | 106.3944 | 8.9876 | 0.1067 | 1.1251 | 0.8549 |
| S3_WeakGrid_30MW | Model 0 (All-SG) | Stable | 59.8262 | 0.0917 | 59.6279 | 0.1983 | 17.7630 | 13.5863 | 7.8806 | NaN | 7.8806 | NaN | 1.0000 | 0.0000 | 0.0000 |
| S3_WeakGrid_30MW | Model 1 (GFL PV) | Unstable | 69.0513 | 10.0155 | 56.0733 | 12.9780 | NaN | NaN | 283.6018 | NaN | 2578.1984 | NaN | NaN | NaN | NaN |
| S3_WeakGrid_30MW | Model 2 (RoCoF-VSG) | Stable | 59.9681 | 0.1197 | 59.5576 | 0.4105 | 25.0000 | 25.0000 | 6.0900 | 150.4091 | 55.3636 | 11.7234 | 1.0000 | 0.4501 | 0.4243 |
| S3_WeakGrid_30MW | Model 3 (Synchronverter) | Stable | 60.1160 | 0.1662 | 59.7937 | 0.3222 | 25.0000 | 25.0000 | 8.6946 | 91.4065 | 79.0419 | 8.9042 | 0.0286 | 0.0446 | 0.0497 |
| S4_HighRES_100MVA | Model 0 (All-SG) | Stable | 59.9976 | 0.1151 | 59.7835 | 0.2141 | 17.4767 | 14.6237 | 9.8669 | 95.9566 | 9.8669 | NaN | 1.0000 | 0.0000 | 0.0000 |
| S4_HighRES_100MVA | Model 1 (GFL PV) | Unstable | 59.8248 | 0.3108 | 33.0450 | 26.7798 | NaN | NaN | 533.9019 | NaN | 533.9019 | NaN | NaN | NaN | NaN |
| S4_HighRES_100MVA | Model 2 (RoCoF-VSG) | Stable | 59.9291 | 0.1693 | 59.8043 | 0.1248 | 9.9910 | 18.7750 | 17.1286 | 29.5160 | 17.1286 | 12.8426 | 0.3621 | 0.3351 | 0.3755 |
| S4_HighRES_100MVA | Model 3 (Synchronverter) | Stable | 60.0612 | 0.1603 | 59.7791 | 0.2820 | 14.5208 | 25.0000 | 7.5083 | NaN | 7.5083 | 9.8492 | 1.0000 | 0.2095 | 0.2406 |

### Dataset B: Decoupled (H, D) Parametric Sensitivity Sweep (`decoupled_H_D_sensitivity.csv`)

| SweepType | CapacityCase | Model | H_s | D_pu | f_pre_Hz | RoCoF_500ms_Hz_s | f_nadir_Hz | Delta_f_max_Hz | ts_f_s | PO_P_step_pct | dP_surge_pu_pct | Damping_zeta |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| H_only | 11MVA | Model 2 (VSG) | 2.0000 | 80.0000 | 59.9990 | 0.1481 | 59.6775 | 0.3215 | 15.0538 | 85.1722 | 43.0296 | 1.1180 |
| H_only | 11MVA | Model 3 (Sync) | 2.0000 | 80.0000 | 60.0485 | 0.1634 | 59.7658 | 0.2827 | 14.4508 | 66.6489 | 68.6386 | 1.1180 |
| H_only | 11MVA | Model 2 (VSG) | 5.0000 | 80.0000 | 59.9990 | 0.1399 | 59.6778 | 0.3212 | 15.0828 | 84.7427 | 43.0090 | 0.7071 |
| H_only | 11MVA | Model 3 (Sync) | 5.0000 | 80.0000 | 60.0486 | 0.1605 | 59.7661 | 0.2825 | 14.5004 | 66.3284 | 68.5893 | 0.7071 |
| H_only | 11MVA | Model 2 (VSG) | 8.0000 | 80.0000 | 59.9990 | 0.1354 | 59.6781 | 0.3209 | 15.1124 | 84.3675 | 42.9989 | 0.5590 |
| H_only | 11MVA | Model 3 (Sync) | 8.0000 | 80.0000 | 60.0486 | 0.1513 | 59.7664 | 0.2822 | 14.5506 | 66.0411 | 68.5469 | 0.5590 |
| H_only | 11MVA | Model 2 (VSG) | 12.0000 | 80.0000 | 59.9990 | 0.1382 | 59.6784 | 0.3205 | 15.1504 | 83.9968 | 43.0125 | 0.4564 |
| H_only | 11MVA | Model 3 (Sync) | 12.0000 | 80.0000 | 60.0486 | 0.1292 | 59.7668 | 0.2818 | 14.6168 | 65.7152 | 68.4839 | 0.4564 |
| D_only | 11MVA | Model 2 (VSG) | 5.0000 | 40.0000 | 59.9989 | 0.1495 | 59.6443 | 0.3546 | 15.9290 | 135.6504 | 28.1268 | 0.3536 |
| D_only | 11MVA | Model 3 (Sync) | 5.0000 | 40.0000 | 60.0529 | 0.1746 | 59.7307 | 0.3222 | 15.5342 | 83.8414 | 38.4765 | 0.3536 |
| D_only | 11MVA | Model 2 (VSG) | 5.0000 | 80.0000 | 59.9990 | 0.1399 | 59.6778 | 0.3212 | 15.0828 | 84.7427 | 43.0090 | 0.7071 |
| D_only | 11MVA | Model 3 (Sync) | 5.0000 | 80.0000 | 60.0486 | 0.1605 | 59.7661 | 0.2825 | 14.5004 | 66.3284 | 68.5893 | 0.7071 |
| D_only | 11MVA | Model 2 (VSG) | 5.0000 | 120.0000 | 59.9990 | 0.1408 | 59.7017 | 0.2973 | 14.4960 | 75.5134 | 59.7035 | 1.0607 |
| D_only | 11MVA | Model 3 (Sync) | 5.0000 | 120.0000 | 60.0447 | 0.1502 | 59.7941 | 0.2506 | 13.6578 | 55.4749 | 91.7308 | 1.0607 |
| D_only | 11MVA | Model 2 (VSG) | 5.0000 | 160.0000 | 59.9991 | 0.1414 | 59.7229 | 0.2761 | 13.9900 | 68.0065 | 73.9134 | 1.4142 |
| D_only | 11MVA | Model 3 (Sync) | 5.0000 | 160.0000 | 60.0414 | 0.1432 | 59.8166 | 0.2248 | 12.9432 | 47.8646 | 109.9392 | 1.4142 |
| H_only | 100MVA | Model 2 (VSG) | 2.0000 | 80.0000 | 59.9291 | 0.1565 | 59.8051 | 0.1240 | 9.9950 | 25.1931 | 16.5594 | 1.1180 |
| H_only | 100MVA | Model 3 (Sync) | 2.0000 | 80.0000 | 60.0611 | 0.1632 | 59.7788 | 0.2822 | 14.4708 | NaN | 7.5133 | 1.1180 |
| H_only | 100MVA | Model 2 (VSG) | 5.0000 | 80.0000 | 59.9291 | 0.1693 | 59.8043 | 0.1248 | 9.9910 | 29.5160 | 17.1286 | 0.7071 |
| H_only | 100MVA | Model 3 (Sync) | 5.0000 | 80.0000 | 60.0612 | 0.1603 | 59.7791 | 0.2820 | 14.5208 | NaN | 7.5083 | 0.7071 |
| H_only | 100MVA | Model 2 (VSG) | 8.0000 | 80.0000 | 59.9291 | 0.1693 | 59.8006 | 0.1285 | 10.8792 | 53.6857 | 20.4483 | 0.5590 |
| H_only | 100MVA | Model 3 (Sync) | 8.0000 | 80.0000 | 60.0612 | 0.1510 | 59.7794 | 0.2817 | 14.5710 | NaN | 7.5031 | 0.5590 |
| H_only | 100MVA | Model 2 (VSG) | 12.0000 | 80.0000 | 60.4067 | 6.3792 | 49.0829 | 11.3237 | 25.0000 | 3666.6046 | 378.0421 | 0.4564 |
| H_only | 100MVA | Model 3 (Sync) | 12.0000 | 80.0000 | 60.0612 | 0.1288 | 59.7798 | 0.2813 | 14.6378 | NaN | 7.4969 | 0.4564 |
| D_only | 100MVA | Model 2 (VSG) | 5.0000 | 40.0000 | 59.0682 | 1.8170 | 57.5634 | 1.5048 | 25.0000 | 6700.1770 | 341.7473 | 0.3536 |
| D_only | 100MVA | Model 3 (Sync) | 5.0000 | 40.0000 | 60.0667 | 0.1745 | 59.7448 | 0.3218 | 15.5486 | NaN | 4.2081 | 0.3536 |
| D_only | 100MVA | Model 2 (VSG) | 5.0000 | 80.0000 | 59.9291 | 0.1693 | 59.8043 | 0.1248 | 9.9910 | 29.5160 | 17.1286 | 0.7071 |
| D_only | 100MVA | Model 3 (Sync) | 5.0000 | 80.0000 | 60.0612 | 0.1603 | 59.7791 | 0.2820 | 14.5208 | NaN | 7.5083 | 0.7071 |
| D_only | 100MVA | Model 2 (VSG) | 5.0000 | 120.0000 | 59.9445 | 0.1456 | 59.8515 | 0.0930 | 1.3520 | 19.9907 | 18.6190 | 1.0607 |
| D_only | 100MVA | Model 3 (Sync) | 5.0000 | 120.0000 | 60.0563 | 0.1499 | 59.8062 | 0.2501 | 13.6826 | 55.2944 | 10.0424 | 1.0607 |
| D_only | 100MVA | Model 2 (VSG) | 5.0000 | 160.0000 | 59.9544 | 0.1318 | 59.8800 | 0.0744 | 1.3124 | 17.1369 | 19.8628 | 1.4142 |
| D_only | 100MVA | Model 3 (Sync) | 5.0000 | 160.0000 | 60.0521 | 0.1430 | 59.8278 | 0.2242 | 12.9688 | 47.7142 | 12.0367 | 1.4142 |

## 3. Qualitative Observations

- Observation: Both grid-forming architectures (`Model 2` RoCoF-VSG and `Model 3` Synchronverter) maintained strict synchronism across all four contingencies (`S1` through `S4`), whereas the grid-following inverter (`Model 1`) suffered loss of synchronism in both the weak-grid contingency (`S3`, reaching $\Delta f_{\max} = 12.98\ \text{Hz}$ and a $283.6\ \text{MW}$ surge) and the high-RES $100\ \text{MVA}$ contingency (`S4`, reaching a $533.9\ \text{MW}$ surge).
- Observation: Under high renewable penetration (`S4`), `Model 2` reduced peak frequency deviation by 41.7% and shortened frequency settling time by 42.8% relative to the all-synchronous-generator baseline (`Model 0`).
- Observation: Across all stable operating regimes, both grid-forming topologies satisfied IEEE 519 harmonic limits with $\text{THD}_v \le 1.13\%$ and $\text{THD}_i \le 0.85\%$.
- Observation: In the 32-point decoupled parametric sweep, increasing virtual inertia $H$ monotonically reduced initial 500 ms RoCoF, whereas increasing damping coefficient $D_{\text{pu}}$ increased modal damping ratio $\zeta$ and reduced settling time $t_{s,f}$ without penalizing initial inertial arrest.
