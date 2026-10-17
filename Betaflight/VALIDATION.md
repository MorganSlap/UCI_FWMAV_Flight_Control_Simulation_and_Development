# Verification performed through the MATLAB MCP server

Validated on 2026-10-12, with additional checks on 2026-10-13, in MATLAB R2025b on Windows. Branch:
`codex/betaflight-simulation`.

Firmware: upstream `c78d9e7bd24ef60f4324dffde11df26c53d4f29f`, native SITL
build with the checked-in host adapter. Compiler: Cygwin GCC 13.5.0.
Current executable SHA-256 (gyro scale corrected on 2026-10-15):
`cf019a9fd46aa609dd02584135fe076e48f9889b810a46d2ea648971c5ceb9da`.
The complete host build succeeded using `build-host.ps1`.

## Native filter mismatch and vibration-induced attitude bias (2026-10-16)

The GUI exposed `accel.LPF_set=5` and `gyro.LPF_set=5`, but neither configured
the replacement native firmware. Betaflight was using `acc_lpf_hz=25`, close
to the model's 24 Hz common-axis wing vibration, and the example had reduced
`imu_dcm_kp` from native 2500 to 250. These are configuration differences from
the original estimator, not a body-axis sign reversal.

`bf.verifyAccelerometerVibration` holds a level fixture, supplies perfect zero
gyro, disables sensor bias/white noise, and feeds controlled 0.1 g vibration
at the physical sensor rate. Native firmware is armed, with Kp=0.25, Ki=0.
The mean estimate over the final 5 s of each 25 s test is:

| Vibration axes | Native accel cutoff | Estimated roll / pitch |
|---|---|---|
| x, y and z in phase | 25 Hz | -0.1156 / +0.1380 deg |
| x, y and z in phase | 5 Hz | 0 / 0 deg |
| x and y only | 25 Hz | 0 / 0 deg |
| z only | 25 Hz | 0 / 0 deg |

Zero here means zero at the native Euler output's 0.1-degree resolution.
Every input vibration component has zero mean. Correlated lateral/vertical
vibration nevertheless biases the mean direction after normalization of the
accelerometer vector. This is consistent with the native Mahony cross-product
calculation and the axis ablations: its false negative roll/positive pitch
estimate makes ANGLE control tilt the real plant positive roll/negative pitch.
The 5 Hz native filter suppresses this effect without removing the simulated
vibration. Report: `test-output/accelerometer-vibration.json` (`Passed=true`).

Closed-loop comparisons retain original drag, seed 23341, full noise/vibration,
fixed throttle and the requested plain rate PI gains. Only the listed native
estimator parameters change:

| Nonlinear case | Accel Hz / Kp / Ki | Final true roll / pitch | Horizontal displacement |
|---|---|---|---|
| Previous noisy hover, 60 s | 25 / 0.025 / 0 | +0.1750 / -0.0683 deg | 5.924 m |
| Filter only, 60 s | 5 / 0.025 / 0 | +0.0923 / +0.0545 deg | 3.198 m |
| Corrected default, 60 s | 5 / 0.25 / 0 | +0.0537 / -0.0204 deg | 3.194 m |
| Integral diagnostic, 60 s | 5 / 0.25 / 0.05 | +0.0628 / -0.0339 deg | 3.193 m |
| Corrected recovery, 10 s | 5 / 0.25 / 0 | -0.0101 / +0.0013 deg | 2.471 m |
| Corrected default, 180 s | 5 / 0.25 / 0 | +0.0557 / -0.0086 deg | 13.881 m |

Across the complete 180 s noisy run, peak absolute roll/pitch is only
**0.08656/0.03461 deg**, versus 0.30457/0.10449 before this correction. During
the last 20 s, true roll stays between +0.0464 and +0.0694 deg and pitch between
-0.0323 and -0.0021 deg. Mean values are +0.0560/-0.0190 deg. The initial
growing-tilt behavior does not persist in this test. Small calibration and
quantization residuals remain; this does not imply perfect zero attitude or
indefinite stability. The fixed-throttle run descends 13.468 m over 180 s.

Recovery starts at +5/-3 degrees, enters and stays within +/-1 degree at
0.87425 s and +/-0.5 degree at 1.56025 s. It previously finished at
+0.515/-0.378 degrees. Estimator integral correction remains at native zero:
the diagnostic does not establish a clear benefit, and it is not applied to
the defaults. These are attitude tests with fixed throttle, not position or
altitude hold. The 60 s corrected default still descends 3.999 m.

The new **Attitude estimator** settings group reads/writes the actual native
CLI and shows Kp/Ki in physical gain units. Values are multiplied/divided by
10000 at the boundary. Native range and precision checks are enforced. The
inactive legacy LPF widgets are removed; old saved settings retain their fields
for compatibility. Native gyro filters remain accessible in the Configurator.
All four supplied example presets now use acc_lpf_hz=5, imu_dcm_kp=2500 and
imu_dcm_ki=0. The script's separate baseline retains its native configuration;
comments explicitly identify its old LPF fields as inactive.

Settings and all signals are archived with **Estimator filter** labels in the
normal GUI library. Reports/plots are `test-output/estimator-filter-*`;
`test-output/runEstimatorFilterCase.m` reproduces the flight cases. No SLX,
sensor-input, native flight algorithm or binary modifications were made.

The direct 180 s hover and 10 s recovery comparison is
`test-output/estimator-filter-comparison.png`; the active GUI controls are shown
in `test-output/attitude-estimator-controls.png`.

All **45 affected regression tests pass**, including a real GUI callback,
actual firmware readback of changed filter/gains, invalid-value rejection,
preset round-trip, all four example/builder comparisons, script initialization
agreement and physics limiting cases. The new native-settings helpers, native
vibration fixture and GUI tests have no Code Analyzer findings. Existing
controller style/performance advisories remain. Both models report `Dirty=off`
and Git shows no SLX changes. The GUI screenshot was inspected to confirm that
the active controls display **5 Hz / 0.25 / 0**, with simulated noise ON.

## Original aerodynamic damping restored (2026-10-15, before filter correction)

The pre-integration script at `4f2f207` sets **CDx=CDy=CDz=CDw=1**.
The integration commit recorded zeros in the script and explicitly overrode
the GUI schema's ones with zeros. Keeping zero drag in the supplied examples
was incorrect. The original values are restored in `lin_hover.m`, the GUI
defaults and all four supplied JSON presets. Historical run archives and
user-saved presets retain their recorded settings. No SLX edit was needed:
both plants and their corresponding ideal IMU already accept these parameters.

All following comparisons retain the corrected gyro calibration/scale,
seed 23341, noise ON, fixed throttle, native estimator gain 250 and the requested
plain PI gains. The restored nonlinear plant and IMU use matching quadratic
drag; the linear pair use matching linearized drag. Logged horizontal specific
force equals the drag acceleration computed independently from the logged
velocities, with maximum discrepancy **0 m/s^2** in all three restored runs.

| Case | Final true roll / pitch | Horizontal displacement | Height loss |
|---|---|---|---|
| Nonlinear, drag OFF, 60 s | +0.295 / -0.109 deg | 25.945 m | 10.636 m |
| Nonlinear, original drag, 60 s | +0.175 / -0.068 deg | 5.924 m | 4.003 m |
| Linear, original drag, 60 s | +0.166 / -0.063 deg | 0.731 m | 0.366 m |
| Nonlinear recovery, original drag, 10 s | +0.515 / -0.378 deg | 3.637 m | 0.352 m |

Recovery enters and stays within +/-1 degree after **1.078 s**. All cases
remain armed in ANGLE mode, finite, and within the motor-command limits;
native D/F terms remain zero. At low speeds, the original linearized damping
is stronger than the nonlinear quadratic damping, explaining the substantial
difference in translation between those plant variants.

A physical limiting-case test also confirms that, at terminal drift velocity,
drag and thrust produce specific force equal to negative body-frame gravity,
recovering both roll and pitch correctly. During acceleration that direct
gravity interpretation is imperfect. Drag restores useful tilt information;
it does not add position or altitude hold.

Settings and data are saved under **Drag restored** labels in the normal GUI
library. Reports are `test-output/drag-restored-{level,recovery,linear-level}`
(`.json`/`.png`), produced by `test-output/checkRestoredDrag.m`.

The **180 s nonlinear** extension peaks at **0.305 deg roll / 0.104 deg pitch**
and finishes at **+0.271/-0.077 deg**. During its last 20 s, roll ranges from
+0.268 to +0.289 deg and pitch from -0.081 to -0.058 deg; fitted slopes are
-0.00049/-0.00054 deg/s. The initial nearly linear roll growth does not continue
throughout this run, but the residual attitude offset is not zero. This finite
test does not establish indefinite stability or position hold: horizontal
displacement at 180 s is 29.862 m. Report:
`test-output/drag-restored-extended-level.json`.

A separate 60 s diagnostic restores native `imu_dcm_kp=2500` instead of the
example's 250. It finishes at +0.198/-0.159 deg, with 11.714 m horizontal
displacement. Stronger correction alone does not remove the offset. This
diagnostic is archived as `drag-restored-native-estimator-gain`; it is **not**
applied to the default examples.

An additional 60 s ablation changes **only accelerometer vibration to zero**,
retaining the example's estimator gain 250, noise ON, sensor white noise/bias,
gyro vibration, calibration seed and PI settings. Final roll/pitch becomes
**+0.092/+0.057 deg**, versus +0.175/-0.068 deg with accelerometer vibration;
horizontal displacement is 3.215 m. This establishes a vibration-dependent
component of the attitude offset, including the negative pitch direction.
It does not demonstrate that all remaining error has one cause or that the
estimator is unbiased. Native gyro calibration uncertainty, integer sensor
offsets and attitude quantization remain. The defaults retain vibration.
Report: `test-output/drag-restored-no-accel-vibration.json`.

The four-panel before/after and 180 s plot is
`test-output/drag-restored-comparison.png`. `checkDragSettling.m` and
`checkDragVibration.m` reproduce the additional diagnostic runs. All saved
archives contain settings, data and lightweight metadata, without model or
initialization-script copies.

All **41 affected regression tests pass**: 24 workbench tests, 13 flight-test
workflow tests and 4 physics limiting-case tests. This includes script/GUI
initialization agreement, all four supplied preset/builder comparisons, the
restored damping defaults and steady-drift tilt recovery. Both loaded models
report `Dirty=off`; Git shows no SLX changes. The diagnostic gain/vibration
settings are confined to their saved runs. The normal examples keep noise and
vibration ON, original drag and the requested PI gains.

## Estimator sign audit and calibration fix (2026-10-15, before drag restoration)

The results in this section are historical **zero-drag** runs, superseded by
the restored-drag defaults above.

The boundary signs are correct. `bf.verifyEstimatorBoundary` feeds supported
tilts of +/-10 degrees independently on roll and pitch; native estimates are
+/-9.9 degrees on the corresponding axis. Gyro-only +/-20-degree rotations
on each of roll, pitch and yaw return the matching signs and angles. A
+/-100 deg/s scaling fixture now returns +/-99.9756 deg/s, within half an ADC
count. The native rotation/truth-isolation test also passed during diagnosis.

Two adapter bugs were identified and corrected:

1. Startup supplied constant bias rather than noisy gyro samples. Native
   calibration learned 8 ADC counts, while noisy flight samples averaged about
   8.2 with the old conversion. The saved baseline independently shows a
   **+0.0122 deg/s** residual on all three axes, matching 0.2/16.384. The adapter
   now supplies white noise at the configured gyro sensor rate and RMS level,
   through the same native ADC/offset-calibration path. It uses a local seeded
   random stream and does not alter MATLAB's global RNG. Calibration remains
   the real firmware algorithm, including movement detection.
2. The host used 16.4 counts/(deg/s), while the native virtual driver actually
   uses 16.384. Conversion now reads the exact driver scale. The native firmware
   algorithms and physical plant were not modified.

The noisy examples also use `gyro_calib_duration=400` (4 s), fitting within
their existing 5 s supported warmup and reducing finite-sample uncertainty.
PI gains, estimator gains, disabled optional PID modifiers and flight noise
remain as requested. Noise OFF disables calibration noise too. Calibration
assumes a quiet supported IMU; wing vibration begins in the flight model.

| Nonlinear case, seed 23341 | Final true roll / pitch | Horizontal displacement | Height loss |
|---|---|---|---|
| Before fixes, noisy level 60 s | -0.568 / -0.969 deg | 118.260 m | 11.158 m |
| Corrected default, noisy level 60 s | +0.295 / -0.109 deg | 25.945 m | 10.636 m |
| Diagnostic only, accel correction OFF, noisy level 60 s | +0.092 / +0.092 deg | 8.148 m | 10.605 m |
| Corrected recovery, noisy 10 s | +0.670 / -0.484 deg | 11.051 m | 0.511 m |
| Corrected noise-OFF level, 10 s | 0 / 0 deg | 0 m | 0.292 m |

Recovery settles within +/-1 degree in 1.084 s. All corrected runs remain armed
in ANGLE mode, have finite results and motor commands inside the configured
range; D/F telemetry stays zero. The 60 s default gyro residual averages
-0.00211/-0.00209 deg/s on roll/pitch, versus about +0.0122 before. The gyro-only
diagnostic (`imu_dcm_kp=0`) isolates the influence of accelerometer feedback;
it is **not** the default and is not a generally drift-free estimator.

The remaining discrepancy is not an inverted sign. With no horizontal drag,
the accelerometer measures body-aligned thrust during accelerating free flight,
not an independent gravity vector. Native Mahony correction pulls toward that
apparent level. Finite gyro-offset error, native integer accel-offset residuals,
vibration/noise and attitude quantization remain; rate PI cannot correct true
tilt the estimator does not observe. No external position/velocity reference
is enabled. The continuing vertical drift is also consistent with fixed throttle
slightly below exact trim, not an altitude-hold test failure.

Raw settings/data are in the normal GUI library under **Estimator fix** labels.
Reports/plots are `test-output/estimator-fix-{level,recovery,noise-off,gyro-only}`
(`.json`/`.png`); sign/scale/calibration fixtures are in `estimator-boundary.json`.
The direct before/after plot is `test-output/estimator-before-after.png`.
All **55 unit tests pass**, including the script/GUI initialization comparison
after forwarding the script's existing `seed` into `bf.simulationOptions`.
Seven changed/new adapter files have zero Code Analyzer findings. Native
arming/failsafe, P-gain scaling, feedforward, yaw sign and fresh-process replay
checks pass with the rebuilt binary. Actual GUI hover/recovery loading passes
with noise ON, and the loaded model remains clean. Existing edited app settings
were preserved; reload a complete example to adopt its 4-second calibration.
The earlier sections below describe results with binary
`ecf7aeb288f687e8642602e313b3cd8cbedc2c720710bd40fb2660621141f60f`
unless explicitly identified otherwise. Historical traces have not been
claimed to replay under the new scale conversion.

## Converted plain PI presets (2026-10-15)

The current noisy hover/recovery examples use native roll P/I/D/F
133/4/0/0 and pitch 134/4/0/0. Optional PID shaping is disabled as listed in
README.md. Betaflight's own CLI accepted the complete configuration and its
effective dump preserved the requested gains and disable settings. Integral
clamping remains 80% of PID-sum limit, PID-sum limit remains 500, ANGLE P remains
20 and sensor filters retain their previous settings. Script defaults,
models and the native executable were not changed for this request.

The shared ANGLE/RATE sequence builders and their JSON presets inherit the same
new baseline. The earlier sequence performance figures below describe P=10,
I=0, and must not be interpreted as results for the new gains.

MATLAB MCP ran the nonlinear plant with noise ON, seed 23341, native 4 kHz
gyro/PID, calibrated simulated sensor offsets and fixed receiver throttle 1859.
Both 10-second cases pass the previously defined `bf.verifyHover` flight criteria.
The 60-second case is an additional drift observation, not an altitude/position
hold acceptance test.

| Case | Final roll / pitch | Peak roll / pitch | Estimator RMS roll / pitch | Horizontal displacement | Height loss |
|---|---|---|---|---|---|
| Level, 10 s | -0.139 / -0.171 deg | 0.139 / 0.171 deg | 0.093 / 0.106 deg | 0.847 m | 0.293 m |
| +5/-3 deg recovery, 10 s | 0.527 / -0.630 deg | 5.000 / 3.001 deg | 0.540 / 0.525 deg | 10.943 m | 0.510 m |
| Level, 60 s | -0.568 / -0.969 deg | 0.568 / 0.969 deg | 0.330 / 0.553 deg | 118.260 m | 11.158 m |

Recovery enters and remains within +/-1 degree after 1.060 s (previous preset:
5.161 s), but residual attitude error and translation remain. At 60 seconds,
the firmware reports roll/pitch of 0/0 degrees while true angles are those in
the table. The native I terms are active (peak 0.0475/0.0476 PID units), and
D/F telemetry is identically zero. Increased rate gains therefore do not remove
the attitude-estimation discrepancy or the resulting drift. No altitude or
position feedback is present; the fixed-throttle deficit also accumulates.

All three runs remain armed in ANGLE mode with finite outputs. Motor commands
stay within 1773.5--1858.0 across the runs. Reports and plots are saved as
`test-output/converted-pi-level-10s`, `converted-pi-recovery-10s` and
`converted-pi-level-60s` (`.json`/`.png`). Full settings/data archives are in
the normal `HoverWorkbench/data` library with labels beginning **Converted PI**.
The presets and historical archives remain settings/data only.

**36 targeted tests pass** (12 flight-workflow/preset tests and 24 workbench
regressions). The latter also verifies that script defaults are preserved.
Actual App Designer startup, recovery loading and hover reloading select the
new settings with noise ON. Code Analyzer reports zero findings in the changed
preset builder and test class. The loaded model remains clean.

## Flight-test workflow (2026-10-14 local)

Added a held physical-reference command sequence, complete ANGLE-pulse and
RATE-doublet presets, and the Flight analysis page. The model files, initialization
script, native firmware binary, physical sensor equations and starting PID gains
are unchanged in this continuation.

**49 unit tests pass:** the existing 39 plus 10 sequence/analysis tests covering
hold boundaries, angle/rate indexing and units, invalid sequence rejection,
older options, JSON round trips, requested command signals, heading wrapping,
and linear/nonlinear altitude-rate conventions. All new MATLAB files have zero
Code Analyzer findings. Existing controller style advisories remain.

| Noisy 10 s run, seed 23341 | Peak roll / pitch | Roll / pitch tracking RMS | Roll / pitch estimate RMS |
|---|---|---|---|
| ANGLE pulses, nonlinear | 4.388 / 4.616 deg | 1.438 / 1.369 deg | 0.069 / 0.187 deg |
| ANGLE pulses, linear | 4.388 / 4.617 deg | 1.438 / 1.370 deg | 0.070 / 0.187 deg |
| RATE doublets, nonlinear | 7.095 / 7.024 deg | 6.487 / 6.485 deg/s | 0.185 / 0.095 deg |

The ANGLE commands are 3-degree roll and -3-degree pitch pulses. The RATE
commands are +/-15 degree/second doublets. All runs remain armed, in the
requested native mode, with finite data, four motors inside 1000--1950 us and
250 us gyro/PID periods. These are bounded integration checks, not tuned
tracking acceptance criteria: ANGLE overshoot and RATE lag are visible. The
aircraft translates during these maneuvers (about 8 m for ANGLE and 15 m for
RATE), and fixed throttle provides no altitude/position hold.

The full nonlinear ANGLE run, including startup, records **40,632 exchanges**.
Requested commands reconstructed from the saved settings match those sent to
firmware with **zero error**. Every one of the 40 response words replays exactly
in a fresh firmware process. See `test-output/flight-angle-high.json`.

All **16 native PID/mixer dividers** and all **five native rate curves** were
rechecked with the current calibration-enabled binary. PID and motor updates
follow their common native task cadence with 4 kHz gyro sampling. Nondefault
channel maps, receiver calibration and yaw reversal also pass; current binary
identity is included in `test-output/timing-current-binary.json`.

Actual GUI callbacks were exercised for complete-example loading, sequence
editing with degree-to-radian conversion, busy-state locking, axis selection,
saved-run selection, the normal Run action and data archival. All six analysis
plots populate (3/2/1/5/4/1 lines). PNG and PDF exports work. Selecting a saved
RATE run leaves the editable ANGLE settings unchanged. A screenshot of the
actual analysis page was inspected. The default noisy hover's peak angles remain
0.1360/0.1769 degrees, and the normal archive contains **107 named signals**.
The run folders contain settings/data/metadata only. See
`test-output/flight-workflow-gui.json` and `flight-analysis-gui.png`.

Analysis-only corrections: nonlinear altitude rate rotates body velocity into
NED; the linear plant retains its zdot=w approximation. Normalized angle errors
wrap at +/-180 degrees. Earlier archives are not rewritten. The newest linear
archive linked from `flight-angle-low.json` uses the corrected analysis.

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

Before the approved sensor corrections, compared the saved model with the original Git blob. Both retained Stateflow
MATLAB Function scripts (nonlinear dynamics and ideal IMU) are identical by
chart name and script content. Retained subsystem XML is unchanged except for
an editor-open flag. The removed subsystems are the old controller and state
estimator; the new referenced firmware model takes their place.

That preservation comparison is historical; the approved IMU and moment-arm
changes are described above. The current continuation does not edit model files.

This verifies the enabled SITL flight-control path and its hover-plant interface.
It does **not** verify physical MCU/peripheral timing, hardware-only protocols,
RPM telemetry, every flight mode, navigation/rescue, or real vehicle behavior.
The explicit limitations and retained plant issues are in [README.md](README.md).

Machine-readable reports and data are under ignored `test-output/`:
`host-verification.json`, `host-traces.mat`, `transport-benchmark.json`,
`plant-verification.json`, `timing-verification.json`, `mode-verification.json`,
`plant-replay-verification.json`, `runs/`, `gui-runs/` and `gui-interface-runs/`.
# App stability and restored noise, 2026-10-17

`test-output/stability-restored-noise.json` records three consecutive runs
through the workbench Run button: nonlinear noisy hover 10 s, recovery 10 s,
and hover 60 s. Each completed/archived and stayed finite/armed. Between runs,
36 total Explore cycles exercised overlay de-duplication, zoom/Home, selected
trace removal, clearing, new/close plot tabs and detached figures. There was
one progress timer throughout and none after app deletion.

Both noise masks omit sample-rate division, restoring the user's lab-matched
convention. Startup gyro noise uses matching variance and native calibration
movement threshold 200. Test filters: gyro PT1 5 Hz with simplified/dynamic/LPF2
disabled, accelerometer native PT2 5 Hz (not identical to the old PT1 transfer
function). Full settings are saved with the runs and in the reusable preset.
The 60 s run reached peak true roll/pitch 1.324/1.228 degrees and final
-0.122/-0.234 degrees. Raw sensor residual STD including vibration was
11.151 deg/s and 0.18868 g. No navigation feedback was supplied; horizontal
displacement was 18.31 m and altitude loss 3.90 m. The larger gyro noise also
increased unobservable heading error (yaw estimator RMS 4.19 degrees).
