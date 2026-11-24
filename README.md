\# WSCC 9-Bus Grid-Forming (VSG / Synchronverter) vs. Grid-Following (GFL) Dynamic Stability Benchmark



A reproducible MATLAB/Simulink Simscape Power Systems benchmark comparing transient frequency stability, inertial support, voltage regulation, and IEEE 519 harmonic distortion across four progressive configurations on the \*\*IEEE / WSCC 9-Bus Test System\*\* ($60\\text{ Hz}$, $110.0\\text{ s}$ duration, $+30.00\\text{ MW}$ step load addition at Bus 5 at $t = 50.0\\text{ s}$).



\---



\## ⚡ 2-Line Quickstart (For Team Collaboration \& Disaster Recovery)



Run these \*\*2 lines in Windows PowerShell\*\* on any laptop to download the entire project (Simulink models, MATLAB scripts, datasets, and plots), verify all theoretical error bounds, and continue working immediately:



```powershell

D:; git clone \[https://github.com/Rajubahardar/BE---Final-year-project.git](https://github.com/Rajubahardar/BE---Final-year-project.git); cd "BE---Final-year-project"

matlab -batch "demo\_all"

```



\*\*macOS / Linux (Bash/Zsh):\*\*

```bash

git clone \[https://github.com/Rajubahardar/BE---Final-year-project.git](https://github.com/Rajubahardar/BE---Final-year-project.git) \&\& cd BE---Final-year-project

matlab -batch "demo\_all"

```



> \*\*Note for Teammates:\*\* Running `"demo\_all"` verifies datasets and generates plots in \*\*< 5 seconds\*\*. To re-run the full $110\\text{ s}$ discrete EMT Simulink sweeps from scratch, run `matlab -batch "demo\_all('resim')"`.



\---



\## 📊 Visual Performance Comparison (GFL vs. VSG)



\### 1. Frequency Nadir, Peak RoCoF \& Settling Time Comparison

!\[GFL vs VSG KPI Comparison](results/gfl\_vs\_vsg\_comparison.png)



\### 2. Theoretical Droop Verification, PCC Voltage Envelope \& IEEE 519 Harmonics

!\[VSG Theory and Harmonics](results/vsg\_theory\_and\_harmonics.png)



\### 3. Model 1 (GFL Baseline) System Response ($+30\\text{ MW}$ Disturbance at $t = 50.0\\text{ s}$)

!\[GFL Baseline Response](results/response\_calib1\_t50.png)



\---



\## 1. Benchmark Model Architecture (Models 0 to 3)



| Model | Simulink File | Automation Script | Control Architecture | Simulation Mode |

| :--- | :--- | :--- | :--- | :--- |

| \*\*Model 0\*\* | `models/WSCC01.slx` | `scripts/run\_kpi\_analysis.m` | \*\*All-Synchronous Base Case\*\* (3 conventional synchronous machines with governors/exciters) | Simscape Power Systems |

| \*\*Model 1\*\* | `models/finalmodel1.slx` | `scripts/wscc9\_kpi\_pipeline.m` | \*\*Grid-Following (GFL)\*\* current-source inverter with PLL ($H\_{\\text{GFL}} = 0\\text{ s}$) | Phasor ($T\_s = 50\\ \\mu\\text{s}$) |

| \*\*Model 2\*\* | `models/finalmodel2.slx` | `scripts/run\_vsg\_kpi.m` | \*\*Virtual Synchronous Generator (VSG)\*\* with swing equation, $Q\\text{–}V$ droop, virtual impedance \& double-loop PI | Discrete EMT ($20\\text{ kHz}$, $11\\text{ MVA} / 400\\text{ V}$) |

| \*\*Model 3\*\* | `models/finalmodel3.slx` | `scripts/run\_synchronverter\_kpi.m` | \*\*Synchronverter\*\* electro-mechanical emulation | Discrete EMT ($20\\text{ kHz}$, $11\\text{ MVA} / 400\\text{ V}$) |



\---



\## 2. Master KPI Results \& Theoretical Error Verification



Evaluated following a \*\*$+30.00\\text{ MW}$ step load addition at Bus 5 ($t = 50.0\\text{ s}$)\*\*:



| Key Performance Indicator (KPI) | Unit | Model 1 GFL (Sim) | Model 1 GFL (Theory) | GFL Error | Model 2 VSG ($H=5\\text{ s}, D=20$) | Model 2 VSG ($H=2\\text{ s}, D=60$) | Model 2 VSG ($H=8\\text{ s}, D=20$) |

| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |

| \*\*Maximum RoCoF ($500\\text{ ms}$)\*\* | $\\text{Hz/s}$ | $0.5019$ | $0.5110$ (Ref)<br>$0.1443$ (COI) | $1.78\\%$ | \*\*$0.1125$\*\* ($-77.6\\%$) | \*\*$0.0934$\*\* ($-81.4\\%$) | \*\*$0.0869$\*\* ($-82.7\\%$) |

| \*\*Frequency Nadir ($f\_{\\text{nadir}}$)\*\* | $\\text{Hz}$ | $59.3648$ | $59.4180$ | $0.09\\%$ | \*\*$59.8586$\*\* ($0.014\\%$ err) | \*\*$59.7078$\*\* ($0.014\\%$ err) | \*\*$59.5429$\*\* ($0.029\\%$ err) |

| \*\*Max Freq. Deviation ($\\Delta f\_{\\max}$)\*\* | $\\text{Hz}$ | $0.6352$ | $0.5820$ | $9.14\\%$ | \*\*$0.3714$\*\* ($2.37\\%$ err) | \*\*$0.3450$\*\* ($2.34\\%$ err) | \*\*$0.3797$\*\* ($4.66\\%$ err) |

| \*\*Steady-State Freq. Dev. ($\\Delta f\_{\\text{ss}}$)\*\* | $\\text{Hz}$ | — | — | — | \*\*$0.1985$\*\* ($1.68\\%$ err) | \*\*$0.1910$\*\* ($2.49\\%$ err) | \*\*$0.1996$\*\* ($2.25\\%$ err) |

| \*\*Frequency Settling Time ($2\\%$)\*\* | $\\text{s}$ | $22.4537$ | $14.3700$ | $56.25\\%$ | \*\*$34.8130$\*\* ($22.05\\text{ s}$ th.) | \*\*$31.0830$\*\* ($19.85\\text{ s}$ th.) | \*\*$33.7130$\*\* ($21.40\\text{ s}$ th.) |

| \*\*PCC Min Voltage ($V\_{\\text{PCC,min}}$)\*\* | $\\text{pu}$ | $0.9946$ | $0.9946$ | $0.00\\%$ | $0.7446$ (underdamped) | \*\*$0.9802$\*\* ($1.98\\%$ sag) | $0.7473$ (underdamped) |

| \*\*PCC Voltage THD ($\\text{THD}\_V$)\*\* | $\\%$ | N/A (Phasor) | $0.00\\%$ | — | \*\*$0.12\\%$\*\* | \*\*$0.47\\%$\*\* | \*\*$0.82\\%$\*\* |

| \*\*PCC Current THD ($\\text{THD}\_I$)\*\* | $\\%$ | N/A (Phasor) | $0.00\\%$ | — | \*\*$1.64\\%$\*\* | \*\*$1.22\\%$\*\* | \*\*$1.27\\%$\*\* |



\### First-Principles Equations Verified in `demo\_all.m`

\* \*\*Virtual Swing Equation:\*\*

&#x20; $$J \\frac{d(\\Delta\\omega)}{dt} = \\frac{P\_{\\text{ref}} - P\_e}{\\omega\_n} - D\\,\\Delta\\omega, \\qquad J = \\frac{2 H\_{\\text{vsg}} S\_{\\text{rated}}}{\\omega\_n^2}, \\qquad D = \\frac{D\_{\\text{pu}} S\_{\\text{rated}}}{\\omega\_n^2}$$

\* \*\*Steady-State Primary Droop Deviation ($\\Delta f\_{\\text{ss,theory}}$):\*\*

&#x20; $$\\Delta f\_{\\text{ss,theory}} = \\frac{\\Delta P\_L}{\\beta\_{\\text{gov}} + \\frac{D\_{\\text{pu}} S\_{\\text{vsg}}}{f\_0}} \\quad (\\text{validated within } 1.68\\%\\text{–}2.49\\%\\text{ of simulation})$$

\* \*\*Dominant-Mode $2\\%$ Settling Time ($t\_{s,\\text{theory}}$):\*\*

&#x20; $$t\_{s,\\text{theory}} = \\frac{-\\ln(0.02)}{\\zeta\\,\\omega\_n}$$



\---



\## 3. Repository Directory Map



```text

BE---Final-year-project/

├── README.md        # Project summary, embedded plots, KPI tables \& 2-line quickstart

├── .gitignore       # Excludes Simulink temporary build caches (slprj/, \*.slxc)

├── demo\_all.m       # 1-command entrypoint for verification, plots \& re-simulation

├── models/          # Simulink models (WSCC01.slx, finalmodel1.slx, finalmodel2.slx, finalmodel3.slx)

├── scripts/         # Automation scripts (run\_kpi\_analysis.m, wscc9\_kpi\_pipeline.m, run\_vsg\_kpi.m, run\_synchronverter\_kpi.m)

├── data/            # Workspace parameter .mat files, vsg\_kpis.mat \& vsg\_kpi\_summary.csv

└── results/         # Simulation response plots \& auto-generated README comparison PNG charts

```

