# WSCC 9-Bus Multi-Domain & Grid-Forming Control Benchmark

## S1 (+30 MW Load Step) Summary

| Model | f_pre (Hz) | RoCoF 500ms (Hz/s) | f_nadir (Hz) | |df_max| (Hz) | dP_peak (MW) | dP/S_rated (%) |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| Model 0 (All-SG) | 59.9976 | 0.1151 | 59.7835 | 0.2141 | 9.87 | 9.87 |
| Model 1 (GFL PV) | 60.0187 | 0.1715 | 59.7076 | 0.3111 | 10.50 | 95.44 |
| Model 2 (RoCoF-VSG) | 59.9990 | 0.1399 | 59.6778 | 0.3212 | 4.73 | 43.01 |
| Model 3 (Synchronverter) | 60.0486 | 0.1605 | 59.7661 | 0.2825 | 7.54 | 68.59 |

## Quick Start
- Run `demo_all` in MATLAB to view all `S1-S4` and 32-point `(H, D)` sweep tables.
- All figures and CSVs are saved in `results/`.
