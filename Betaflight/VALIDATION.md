# Verification performed through the MATLAB MCP server

Validated on 2026-10-12, with additional checks on 2026-10-13, in MATLAB R2025b on Windows. Branch:
`codex/betaflight-simulation`.

Firmware: upstream `c78d9e7bd24ef60f4324dffde11df26c53d4f29f`, native SITL
build with the checked-in host adapter. Compiler: Cygwin GCC 13.5.0.
Executable SHA-256:
`ecf7aeb288f687e8642602e313b3cd8cbedc2c720710bd40fb2660621141f60f`.
The complete host build succeeded using `build-host.ps1`.

## Current noisy example and approved corrections (2026-10-13 local)

All four model corrections were explicitly approved and applied through the
MATLAB MCP server. Both plants compile and execute with `bf.idealImu`, the
corrected noise-power units and nonlinear moment arm `S`.

Default: noise ON, seed 23341, ANGLE mode, 1859 us fixed throttle, native
`imu_dcm_kp=250`, unchanged rate gains P=10/I=D=F=0, and explicitly enabled
ideal bench accelerometer calibration. That option derives native offsets from
known simulated bias: [-5,-5,-5] counts when noise is ON and zero when OFF.
It does not estimate bias in flight or feed true attitude into the estimator.
Disabling the option preserves manual CLI calibration values.

| 10 s case, seed 23341 | Final roll / pitch | Horizontal displacement | Height change |
|---|---|---|---|
| Noisy nonlinear, level | -0.1360 / -0.1769 deg | 0.7132 m | -0.2926 m |
| Noisy linear, level | -0.1360 / -0.1769 deg | 0.7136 m | -0.2919 m |
| Noisy nonlinear, +5/-3 deg recovery | 0.4891 / -0.5799 deg | 3.7837 m | -0.6524 m |

Recovery remains within 1 deg after 5.1609 s. The nonlinear level case's
roll/pitch estimation RMS error is 0.0827/0.1070 deg. All runs remain armed in
ANGLE mode at 250 us gyro/PID/mixer timing. A second noisy level run with seed 1
also passes (peak roll/pitch 0.157/0.194 deg, horizontal displacement 0.808 m).
The corrected noise-OFF level case has zero angle/horizontal drift and loses
0.2921 m height from the quantized fixed-throttle mismatch.

Raw/ideal IMU logging confirms nonzero noise. With noise ON, measured-minus-
ideal standard deviations are about 0.695 m/s^2 and 2.625 deg/s, dominated by
the retained wing vibration. Noise OFF gives exactly zero measured-minus-ideal
error in the level run. Original common vibration and shared per-axis random
seeds are retained; this is a correlated-noise model.

The noisy criteria are explicit: final roll/pitch under 1 deg; level peak under
1 deg, horizontal displacement under 1 m, height change under 0.35 m and down
speed under 0.08 m/s; recovery peak under 6 deg and settling within 1 deg. These
criteria assess short attitude-stabilized near-hover, not altitude/position hold.

**39 tests passed:** 12 configuration, 24 workbench, 3 physical limiting cases.
The actual GUI toolbar toggles noise correctly, the noisy 10 s Run callback
completes without error, and its normal library saves **104 signals** including
the four ideal/measured IMU vectors. Presets, display and effective native
calibration follow the selected noise state. No source/model snapshots are saved.

A new noisy, calibrated 0.5 s Simulink capture (including startup) replays
**all 2,632 exchanges exactly** in a fresh firmware process. All 40 response
words match; see `test-output/noisy-calibrated-replay.json`. New `+bf` files
have no Code Analyzer findings. The existing five `+hover` and eight controller
style advisories remain; `git diff --check` passes.

Current flight artifacts are `hover-<case>-<plant>-noise-on-seed23341.json/.png`
under `test-output`, plus the noise-OFF and seed-1 checks. `imu-noise-on.png`
shows full-duration noise and a 0.5 s detail. Each report points to its complete
settings/data archive. See [CHANGE_SUMMARY.md](CHANGE_SUMMARY.md) for attribution.

## Earlier noise-off baseline, before the sensor corrections

The user selected attitude stabilization with trimmed throttle and confirmed
there is no altitude sensor. The example supplies no barometer, GPS,
magnetometer, altitude feedback or position feedback. Noise is disabled for
this initial baseline. Every firmware setting and plant input is prefilled in
the app and in `presets/imu-only-hover.json`; `presets/attitude-recovery.json`
adds +5 degrees initial roll / -3 degrees pitch.

The rebuilt executable runs the original gyro calibration routine. Upstream
SITL's virtual-gyro bypass previously left simulated bias uncompensated. A
four-second independent rotation fixture with nonzero gyro bias now gives:

| Check | Result |
|---|---|
| Stationary calibrated gyro | [0, 0, 0] deg/s |
| Roll / pitch / yaw RMS error | 0.0418 / 0.0359 / 0.1453 deg |
| Roll / pitch / yaw peak error | 0.1576 / 0.1280 / 0.2195 deg |
| Arbitrarily changed truth-state inputs | Exactly identical firmware response |

Both transports, native PID/FF response, all motor-axis signs and receiver-loss
failsafe pass `bf.verifyHost` with this binary. **38 unit tests pass**: 12
configuration, 23 workbench and 3 physical limiting cases for the prepared IMU
helper. The native roll-P ratio remains exactly 2 and feedforward peak 21.9622.

| 10 s case | Final roll / pitch | Height change | Final down speed |
|---|---|---|---|
| Nonlinear, level | 0 / 0 deg | -0.2921 m | 0.0587 m/s |
| Linear, level | 0 / 0 deg | -0.2921 m | 0.0587 m/s |
| Nonlinear, +5/-3 deg recovery | 0.1124 / -0.0595 deg | -0.7001 m | 0.1065 m/s |

The recovery settles and stays within 0.5 deg after **5.3362 s**, with maximum
roll/pitch magnitudes 5/3 deg. Its roll/pitch estimator RMS error is
0.0420/0.0508 deg. Final horizontal displacement is 0.8095 m. The level cases
have zero horizontal displacement. All runs stay armed in ANGLE mode and log
native gyro/PID/mixer operation at 250 us. Simulation wall time is about
14 seconds per 10-second run, excluding figure export and archive writing.

Fixed throttle is **1859 us**, chosen from native firmware measurements around
the analytic trim. Mean motor output is 1815.748657, while the plant requires
1816.102620. The input quantization leaves a small thrust deficit and descent.
This is a near-hover baseline with attitude stabilization, not altitude hold.

**At this earlier stage, sensor-model correction was pending approval.** The then-current Simulink ideal
IMU still rotates gravity into its free-flight measurement and gates physical
acceleration with `noise_true`; white-noise power has a sample-time scaling
error; the nonlinear arm-length port is supplied with mass. The prepared
`bf.upgradeFlightInterfaces` had not been applied. Unit tests of `bf.idealImu`
do not mean the model uses it. Current recovery results must therefore be
treated as baselines under the existing sensor chart. `bf.flightInterfacesReady`
returned false, and new sensor editors were hidden until installation. This
restriction is resolved by the explicitly approved corrections above.

Current reports/figures and settings/data archives are under `test-output/`:
`estimator-verification.json`, `estimator-rotation.mat`, `host-verification.json`,
`hover-level-high.json/.png`, `hover-level-low.json/.png`,
`hover-recovery-high.json/.png`, and their `RunFolder` archives.
No script or model is copied into a run archive.

The GUI's actual Run simulation callback also completed the full 10-second
default case, populated all four default axes (12/4/6/6 lines), and saved 92
signals with settings in its normal `HoverWorkbench/data` library. No runtime
error was reported. New `+bf` files have no Code Analyzer findings; five
pre-existing style advisories remain in `+hover`. `git diff --check` passes.

## Previous integration checks

The checks below were performed with the earlier binary
`2929e352aac00e37730d6606fc66e77d1083babafe1cb5c435d9784ea027c622`.
Timing/mode and complete plant replay coverage below is historical, not a claim
that those recorded files replay under the rebuilt calibration-enabled binary.
Older exact traces require their original executable. Their bounded-attitude
criterion did not prove hover: the old nonlinear case drifted about 13.8 m
north and 2.57 m down. Use the explicit current flight metrics above instead.

* **12 configuration tests passed**: CLI formats, scoped edits, profile selection,
  validation, JSON/CLI round trips, command preservation, actual battery-profile
  scope, remapped receiver/AUX channels, calibrated endpoints/center, custom
  startup pulses, final AUX assignment precedence and independent PID timing.
* **21 workbench regression tests passed** (19 initially; the two empty-struct
  comparison failures passed after correcting the test helper). The script
  initialization comparison includes the new firmware/adapter variables.
* **Standalone firmware checks passed**: calibration and arming through native
  receiver processing; combined +5° roll/−3° pitch attitude; gyro scaling/signs;
  native rate conversion; all three motor-axis patterns; native failsafe/disarm;
  exact replay across fresh processes and both transport implementations.
* Doubling native roll P produced exactly **2×** the recorded P term. Enabling
  feedforward produced a peak native F term of **21.9622**, versus zero with F=0.
  Positive 10°/s yaw input produced positive heading in the model convention.
* Both reference/top-level models compiled. The unchanged linear and nonlinear
  plants each completed **10 simulated seconds**, with **40,001 controller
  samples** at **250 µs**, four motors, finite outputs, no unexpected disarming,
  and motor commands within **1000–1950 µs**.
* Both runs saved and reloaded the exact firmware settings and **92 named
  signals**, with no script/model source snapshots in the archive.
* The original `lin_hover.m` initialization → simulation → figures workflow
  completed successfully in **19.23 s** in the final script check.
* The workbench's actual **Run simulation** path completed a 0.25 s smoke run,
  displayed plots, and automatically archived its settings/data with no error.
  Configurator Apply, JSON reload, tree double-click plotting and default plots
  were exercised through the GUI's actual callback methods.
* **All 16 PID dividers passed** with 4 kHz sensor input. Observed P-term and
  motor changes occur on the same native PID task cadence. The cases exercise
  all five native rate curves, rate profile 1, `TAER4321` mapping, nondefault
  receiver endpoints and yaw reversal. Custom throttle endpoints initially
  prevented arming; the adapter now uses the calibrated minimum and converts
  hover throttle back to the physical input range.
* **Complete Simulink replay passed for both plants** at 4 kHz sensor sampling
  and 1 kHz PID/mixing. Each one-second plant run contains **4,532 exchanges**,
  including warmup and arming. Every response word is exactly equal in a fresh
  native process. The linear-plant recording also replays exactly through the
  alternate MATLAB `tcpclient` transport.
* **Three native mode scenarios passed through the referenced model**: ARM
  requiring both AUX 1 and AUX 3; direct ANGLE; raw-receiver HORIZON; and ANGLE
  linked to BEEPER. These are targeted activation checks, not exhaustive flight
  performance tests for every mode.
* The new **Receiver channels** table and **PID/mixer frequency** dropdown were
  exercised through their actual callbacks. Custom pulses and divider 4 saved,
  reloaded and completed a 0.25 s GUI simulation with automatic archival.
* Code Analyzer reported no issues in the new `+bf/*.m` files at the final
  analysis pass; `git diff --check` passed.

| Plant | Peak absolute roll / pitch | Final roll / pitch | Final yaw |
|---|---|---|---|
| Nonlinear | 5.000° / 3.164° | −1.354° / −3.161° | 0.052° |
| Linear | 5.000° / 3.165° | −1.353° / −3.162° | 0.000° |

These checks establish a bounded starting simulation, not accurate real-aircraft
tuning. Residual pitch offset and unobservable yaw/position behavior remain
subject to the existing sensor/plant model and chosen tuning. The preset uses
P=10, I/D/F=0 and Anti Gravity gain=0 on the slow flapping-wing plant.

## Transport measurement

With profiling disabled for both measurements, 500 identical packets took
**5.1199 s** through MATLAB `tcpclient` and **0.0716 s** through the Java socket
channel: **71.5× faster for this packet-exchange test**, with exactly equal
response arrays. This is not a 71.5× claim for complete simulations. The original
profile showed most packet time inside `tcpclient.read`; the change only removes
that communication overhead. Native firmware calculations and simulated timing
are unchanged.

## Model preservation and remaining boundaries

Compared the saved model with the original Git blob. Both retained Stateflow
MATLAB Function scripts (nonlinear dynamics and ideal IMU) are identical by
chart name and script content. Retained subsystem XML is unchanged except for
an editor-open flag. The removed subsystems are the old controller and state
estimator; the new referenced firmware model takes their place.

This verifies the enabled SITL flight-control path and its hover-plant interface.
It does **not** verify physical MCU/peripheral timing, hardware-only protocols,
RPM telemetry, every flight mode, navigation/rescue, or real vehicle behavior.
The explicit limitations and retained plant issues are in [README.md](README.md).

Machine-readable reports and data are under ignored `test-output/`:
`host-verification.json`, `host-traces.mat`, `transport-benchmark.json`,
`plant-verification.json`, `timing-verification.json`, `mode-verification.json`,
`plant-replay-verification.json`, `runs/`, `gui-runs/` and `gui-interface-runs/`.
