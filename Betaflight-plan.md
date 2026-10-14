# Betaflight simulation integration

Branch: `codex/betaflight-simulation`, based on the current checkout, preserving
the user's uncommitted zero-drag changes in `lin_hover.m`.

Use the actual upstream Betaflight SITL flight stack, pinned to an immutable
commit, with an isolated host adapter for deterministic Simulink stepping.
The adapter must not replace the firmware PID, filtering, estimator, receiver,
flight modes, arming/failsafe, or mixer algorithms with MATLAB approximations.
Hardware features absent from the upstream SITL target must be listed explicitly.

## Interfaces and implementation

- Inspect and retain both existing plant variants, actuator model, physical
  sensor models, and state/controls/estimate logs used by existing plots.
- Put the firmware boundary in its own referenced model. Use documented
  Simulink blocks for sample timing and a MATLAB System or Level-2 S-function
  to exchange fixed-shape sensor/receiver inputs and actuator/estimate outputs.
- Translate SI sensor data and actuator delta-pot conventions explicitly.
  Preserve four-actuator order and validate each sign with isolated inputs.
- Run firmware in lockstep against simulated time, with one process/state
  instance per simulation and bounded transport timeouts.
- Initialize configuration using the firmware's own CLI parser and parameter
  definitions. Expose all available settings and full CLI import/export.
- Extend the established MATLAB GUI architecture with native grid layouts,
  grouped tuning controls and searchable advanced settings; save settings and
  data rather than source snapshots.

## Verification

1. Build pinned upstream firmware and document the exact host-only patch.
2. Exercise firmware defaults/config round trips, arming/failsafe, sensor signs,
   motor order/limits, fixed simulated timing and reset/repeatability.
3. Compile referenced and top-level models in MATLAB through the MCP server.
4. Run both linear and nonlinear plants, preserve plotting field dimensions,
   and compare recorded adapter exchanges against standalone firmware runs.
5. Test GUI edits/config export, saved runs and signal plotting.

Continuation verified on 2026-10-13: separate 4 kHz sensor and native PID/mixer
timing (all 16 dividers), receiver endpoint/center and custom startup pulses,
AND/linked mode activation, and exact complete Simulink replay against fresh
firmware for both plants. The receiver table and PID-frequency control were
exercised through GUI callbacks and a saved/reloaded run. Navigation and
hardware-only target features remain outside the verified coverage listed in
`Betaflight/VALIDATION.md`.

Current priority: IMU-only attitude stabilization at fixed trimmed throttle;
the user explicitly confirmed there is no altitude sensor. Added complete level
and attitude-recovery presets, measured drift/settling plots, and enabled the
native gyro calibration that upstream virtual-gyro builds skip. The 10 s level
case and recovery test passed with the original model. The user subsequently
explicitly approved all four corrections: specific force, sensor noise power,
exposed sensor parameters, and the nonlinear arm-length input. They are now
installed and both plants compile/run. Noise defaults ON, with a visible toolbar
toggle, matching saved presets, and raw/ideal IMU logs. The noisy example uses
native imu_dcm_kp=250 and explicit ideal bench accelerometer calibration from
known simulated bias. On/off, noisy recovery, both plants and GUI runs pass;
39 unit tests pass. Results and attribution are in Betaflight/VALIDATION.md
and Betaflight/CHANGE_SUMMARY.md. No altitude sensor or loop has been added.

References: MATLAB app-building skill (`references/uifigure/guide.md`, existing
App Designer architecture); MATLAB documentation skill for installed Simulink
API signatures; official Betaflight SITL implementation and build instructions.
Portable toolchains and run data remain local ignored artifacts.
