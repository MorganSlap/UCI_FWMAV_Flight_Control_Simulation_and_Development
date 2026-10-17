# Betaflight simulation integration

Branch: `codex/betaflight-simulation`. The original pre-integration script has
CDx=CDy=CDz=CDw=1. These values are restored in the script and all supplied GUI
examples; zero drag is not the user's intended default. The earlier attribution
of the zero-drag settings to the user was not established by the Git history.

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

## Continuation: repeatable flight tests and tuning analysis (2026-10-14)

Extend the existing App Designer external controller, using its grid-layout
settings editor and tiled plots. Add an optional held command sequence in the
host's physical-reference adapter, with angle-pulse and rate-doublet examples.
The native receiver, estimator, PID and mixer continue processing those commands.
Save the sequence with settings and expose requested commands beside measured
responses in Explore. Add a Flight analysis page for tracking, estimator error,
native P/I/D/F contributions and motor outputs, with saved-run selection.
Keep the default noisy hover case and model/script unchanged. Validate command
boundaries, preset round trips, both plant variants, actual GUI callbacks and
exact firmware replay for a changing-command run. Recheck native timing on the
current calibration-enabled binary. No new flight-control law or altitude
feedback is introduced.

Completed and verified: 49 unit tests; noisy 10-second ANGLE cases for both
plants and nonlinear RATE doublets; all 40,632 exchanges from the full ANGLE
case replay exactly; all 16 native PID/mixer dividers and five rate curves
rechecked with the current binary. The actual GUI Run callback preserves the
default noisy hover result and saves 107 signals. Sequence editing, saved-run
selection, axis selection and PNG/PDF export pass. Starting gains remain
untuned for the new maneuvers; overshoot/lag are explicitly reported. Model,
initialization script and native binary remain unchanged in this continuation.

## Requested converted PI defaults (2026-10-15)

Completed: noisy hover/recovery use native roll 133/4/0/0 and pitch 134/4/0/0
P/I/D/F with optional PID modifiers disabled through supported CLI values.
Shared sequence examples and all four shipped JSON presets are consistent.
Firmware CLI round trip, 36 targeted unit tests and actual GUI example-loading
callbacks pass. Both noisy 10-second hover/recovery cases pass the existing
criteria; recovery reaches +/-1 degree in 1.06 s. The additional 60-second
level test retains attitude-estimation error and substantial translation, as
recorded in Betaflight/VALIDATION.md. No model, script, estimator or binary
changes were made to hide this behavior. All runs are saved in the GUI library.

## Estimator audit and calibration correction (2026-10-15)

Completed the requested sign/bug investigation. Supported +/-roll/pitch tests
and gyro-only +/-rotation tests on all axes pass. Fixed two adapter bugs:
constant startup gyro samples biased native calibration relative to noisy
flight samples, and host conversion used 16.4 instead of native 16.384 counts
per degree/second. Startup now models sensor-rate gyro white noise and native
averaging; noisy examples use a 4 s calibration within 5 s warmup. The script
passes its existing noise seed into adapter initialization. Models and native
flight algorithms remain unchanged; the host executable was rebuilt.

Verified 55 unit tests, native sign/scale/calibration/arming/failsafe/replay
checks, GUI example loading, noisy 60 s hover, noisy 10 s recovery, a noise-OFF
control and a 60 s gyro-only diagnostic. Corrected 60 s roll/pitch is
+0.295/-0.109 deg versus -0.568/-0.969 before. Remaining drift comes from finite
gyro calibration and the accelerometer's lack of an independent gravity
reference during zero-drag accelerating flight, plus noise/quantization.
The gyro-only diagnostic is not the default. Before/after plots, saved runs,
the exact binary hash and limitations are recorded in Betaflight/VALIDATION.md.

## Restore the original drag configuration (2026-10-15)

Restored original CDx=CDy=CDz=CDw=1 in the initialization script, GUI defaults
and all four complete example presets. Removed the explicit GUI zero override.
No SLX changes were necessary. Closed-loop logged specific force exactly matches
the corresponding linear or quadratic drag acceleration in both plant variants.
Noisy nonlinear hover at 60 s improves from 25.945 m to 5.924 m horizontal
displacement and from +0.295/-0.109 deg to +0.175/-0.068 deg roll/pitch.
At 180 s the restored-drag attitude has a small nonzero offset and is no longer
following the initial straight-line trend; it peaks at 0.305/0.104 deg.
The requested PI settings, estimator settings and noisy defaults are preserved.
Stronger native accelerometer correction was tested separately and did not
eliminate the offset. Details and saved-run labels are in VALIDATION.md.

## Native filtering and attitude-control correction (2026-10-16)

Identified inactive legacy LPF widgets: the GUI showed 5 Hz but native accel
filtering was 25 Hz. A constrained level fixture with perfect gyro reproduced
false roll/pitch from common-axis 24 Hz vibration; reducing the actual native
cutoff to 5 Hz removed the displayed bias. Axis ablations isolated the effect
of correlated lateral/vertical vibration in gravity-vector normalization.
Added active native filter/Kp/Ki controls with physical gain units and preserved
all raw native values in saved configurations. Complete examples now use native
acc_lpf_hz=5, imu_dcm_kp=2500 (0.25) and imu_dcm_ki=0. The original drag, noise,
vibration and requested rate PI settings remain. Estimator Ki=0.05 was tested
separately and not adopted. The noisy 180 s run stays within 0.0866/0.0346 deg
roll/pitch and ends at +0.0557/-0.0086 deg. Recovery reaches +/-1 degree after
0.874 s and finishes near zero. Models and firmware binary were not changed.
