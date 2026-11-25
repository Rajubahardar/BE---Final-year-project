## Problem Statement
Replacing synchronous generators with inverter-based resources (IBRs) reduces grid rotational inertia and weakens short-circuit strength at the point of common coupling (PCC). Conventional grid-following (GFL) inverters rely on a phase-locked loop (PLL) to track grid voltage angle and inject current; under weak-grid conditions characterized by high line impedance and low short-circuit ratio (SCR), PLL synchronization dynamics interact adversely with grid impedance, causing frequency excursions and loss of synchronism. Existing evaluations often isolate single-bus approximations or lack standardized multi-domain comparisons across both electromagnetic transient (EMT) and phasor representations.

## Core Hypothesis
We hypothesize that replacing PLL-dependent current-source injection with grid-forming (GFM) virtual synchronous machine control—specifically a Rate-of-Change-of-Frequency enhanced Virtual Synchronous Generator (RoCoF-VSG) and an electromechanical Synchronverter—will preserve synchronism across weak-grid and high-penetration contingencies on a multi-machine transmission network while decoupling inertial frequency arrest from oscillation damping.

## Proposed Methodology (Detailed Technical Approach)
We will construct a multi-domain EMT and phasor benchmark on the standard 3-machine, 9-bus, $60\ \text{Hz}$ WSCC transmission network in MATLAB/Simulink using fixed-step `ode4` integration at $T_s = 50\ \mu\text{s}$ (with $T_s = 25\ \mu\text{s}$ cross-verification).

1. **RoCoF-Enhanced Virtual Synchronous Generator (`Model 2`):**
   We formulate the virtual rotor swing dynamics in per-unit as:
   $$2H \frac{d\omega_v}{dt} = P_{\text{ref}} - P_e - D_{\text{pu}}(\omega_v - \omega_0) - k_{\text{rocof}} \frac{d\omega_{\text{PCC}}}{dt}$$
   where $H = 5.0\ \text{s}$ is the virtual inertia constant, $\omega_v$ is the internal virtual angular frequency, $\omega_0 = 2\pi(60)\ \text{rad/s}$ is the nominal synchronous speed, $P_{\text{ref}}$ is the active power setpoint, $P_e$ is the measured instantaneous three-phase active power at the inverter terminal, $D_{\text{pu}} = 80\ \text{p.u.}$ is the damping coefficient, and $k_{\text{rocof}}$ is the derivative RoCoF feedforward gain acting on the PCC frequency derivative $d\omega_{\text{PCC}}/dt$. The internal phase angle is integrated via $\theta_v = \int \omega_v\,dt$, and reactive power droop regulates the internal voltage magnitude $E_v$:
   $$E_v = E_0 + K_q (Q_{\text{ref}} - Q_e)$$
   where $E_0$ is the nominal terminal voltage, $K_q$ is the reactive droop gain, $Q_{\text{ref}}$ is the reactive power setpoint, and $Q_e$ is the measured reactive power.

2. **Electromechanical Synchronverter (`Model 3`):**
   We formulate an electromechanical stator-rotor model governed by virtual mutual inductance $M_f i_f$ and mechanical swing equation:
   $$J \frac{d\omega_m}{dt} = T_m - T_e - D_p(\omega_m - \omega_0)$$
   where $J$ is the virtual moment of inertia, $\omega_m$ is the virtual rotor speed, $T_m$ is the mechanical torque input, $T_e = M_f i_f \langle i, \widetilde{\sin}\theta \rangle$ is the electromagnetic air-gap torque computed from three-phase stator current $i$, and $D_p$ is the mechanical friction/droop damping factor. The back-EMF vector $e = \omega_m M_f i_f \widetilde{\sin}\theta$ feeds a cascaded inner voltage and current double closed-loop controller with LCL output filtering.

3. **Benchmark Evaluation Protocol:**
   We will evaluate four topologies—`Model 0` (All-SG Phasor baseline), `Model 1` (GFL PV EMT), `Model 2` (RoCoF-VSG EMT), and `Model 3` (Synchronverter EMT)—across four contingencies (`S1`: $+30\ \text{MW}$ load step; `S2`: $-45\ \text{MW}$ load shed; `S3`: weak grid with $2\times Z_{\text{line}}$ and $\text{SCR} \approx 1.5$; `S4`: high-RES $100\ \text{MVA}$ inverter base) using 10 transient and power-quality KPIs, followed by a 32-point decoupled $(H, D_{\text{pu}})$ sensitivity sweep.

## Expected Contribution
1. A reproducible multi-domain EMT/phasor benchmark suite on the WSCC 9-bus network evaluating GFL and GFM inverter architectures under identical transmission contingencies.
2. Quantitative demonstration of weak-grid loss-of-synchronism mechanisms in GFL inverters versus continuous synchronism in RoCoF-VSG and Synchronverter controllers across 10 transient and harmonic KPIs.
3. Decoupled design guidelines mapping virtual inertia $H$ and damping $D_{\text{pu}}$ independently to RoCoF arrest and modal damping ratio.