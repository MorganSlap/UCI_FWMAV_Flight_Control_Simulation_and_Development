# Desktop software-in-the-loop build

Development branch: feature/SITL_sim_Codex. Desktop work originated on
codex/desktop-sil and was merged back. Preserve lin_hover_sim.slx and the MATLAB workbench.

1. Copy the existing actuator, dynamics and sensor blocks into a dedicated
   plant with motor-delta input and true-state/raw-IMU outputs. Generate C using
   Embedded Coder, with tunable physical parameters and an explicit solver.
2. Compile and compare generated plant outputs with the equivalent Simulink
   plant under identical inputs, initial states and random seeds.
3. Connect the generated plant and pinned Betaflight firmware in a standalone
   desktop loop. Preserve startup/calibration, receiver scheduling and units.
4. Provide desktop controls, run storage and plots, with run configuration
   independent of rebuilding the executable. Validate noisy hover/recovery.

Sample-rate constraint: 4 kHz firmware, 3.2 kHz gyro and 1.6 kHz accelerometer
require a 16 kHz common plant time base. Rendering is independent of this loop.
Code generation is from copied Simulink blocks, not a hand-transcribed plant.

Implemented and verified on November 1, 2026. Both generated plants now use
ODE5, with 16/32/64 kHz integration selectable independently of firmware rates.
See PARITY.md for completed UI coverage and verification/*.json for numerical,
firmware replay, long-run convergence and desktop workflow evidence.
