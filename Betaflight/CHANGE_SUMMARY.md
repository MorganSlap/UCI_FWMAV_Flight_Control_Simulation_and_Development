# Noise-enabled example and model corrections

Branch: `codex/betaflight-simulation`. The original integration is committed as
`1b3143f`; subsequent flight-test, calibration, UI, plotting and preset changes
are documented below.

## Make the tested 5 Hz filters the simulation defaults (2026-10-17)

- Base hover configuration, new workbench sessions and all four supplied
  examples/presets use gyro LPF1 PT1 at 5 Hz, simplified gyro tuning OFF,
  dynamic minimum 0 (disabled), LPF2 0 (disabled), and accelerometer PT2 at 5 Hz.
  The script inherits the same defaults when creating a new `bf.hoverConfig`.
  Previously saved user settings and run archives are preserved.
- Added a native firmware readback check for all six filter settings, in
  addition to the existing shipped-preset parity checks. All 86 workbench,
  firmware-configuration, flight-physics and calibration tests pass through
  MATLAB MCP with the new defaults.

## Repair Flight analysis and clarify its plots (2026-10-17)

- Reproduced the empty page with the user's saved `hover test orig noise 5 hz
  filters` run. The recent rendering optimization switched the shared helper
  from `plot` to `line`, while Flight analysis still supplied positional line
  styles. `line` rejects those arguments. This was a regression introduced by
  that app update, not a simulation or saved-data failure.
- Changed analysis calls to explicit `LineStyle` properties. The controller
  now retains the caught report in `LastAnalysisError`. Earlier stability
  checks covered Default/Explore but missed this caught analysis failure.
- Added explanations, units and consistent truth/estimate colors. ANGLE
  roll/pitch now show angular rate feedback in the second panel, rather than
  repeating attitude. Rate/yaw tests retain the complementary attitude panel.
  Receiver-mode runs can use logged native rate commands. Estimation and
  tracking errors are distinguished; motor outputs include a hover-trim line;
  the raw gyro panel explicitly identifies measurement error before calibration
  and filtering. Missing logs get explanatory messages.
- Full-duration Home and detached plots retain the data and explanations.
  Seven new analysis tests and 17 existing plot/stability tests pass through
  MATLAB MCP, including the actual app callback and all six nonempty panels.
  The user's saved hover now displays all six plots. No flight rerun, firmware,
  model, initialization-script, calibration or noise changes were needed.

## App stability, run setup and restored lab noise (2026-10-17)

- Found and disposed 17 orphaned workbench timers/controllers, including saved
  run data retained after direct app deletion. Figure destruction now owns
  controller cleanup. Run/load/plot callbacks are guarded through finalization;
  repeated selection of the same run/signal does not accumulate duplicate lines.
  Viewport rendering uses manual limits and skips unchanged viewport updates.
- Run setup now combines case selection, fidelity, duration, noise/seed, drag,
  mode, throttle and command sequence. Removed decay-time damping editors;
  app runs use reference-speed drag. Disabling drag sets all effective CDs to
  zero while retaining user-entered coefficients. Gyro and accelerometer have
  separate panels with active firmware filter controls.
- Restored both white-noise mask powers at the user's request: density squared
  times bandwidth, without sample-rate division. No other plant equations or
  sensor settings changed. Startup gyro noise matches the increased variance;
  plant presets use the supported calibration movement threshold of 200 ADC
  counts. Previously saved user presets retain their native threshold.
- Exposed raw gyro/accelerometer X/Y/Z in SI and display units, before firmware
  calibration/filtering. Existing archives with IMU logs gain these names on
  load; archived measurements are not rewritten.
- Three consecutive app runs passed (10 s hover, 10 s recovery, 60 s hover), with
  36 zoom/Home/overlay/removal/new/close cycles and detached figures between
  runs. Timer count stayed at one while open and zero after closing.
- Test filters: simplified gyro tuning OFF, gyro LPF1 PT1 static 5 Hz, dynamic
  minimum 0 (disabled), LPF2 0 (disabled), native accelerometer PT2 at 5 Hz.
  Drag/noise ON, seed 23341. The 60 s true roll/pitch peaks were 1.324/1.228 deg;
  final values -0.122/-0.234 deg. Estimator roll/pitch RMS error 0.515/0.516 deg.
  Raw measured-minus-ideal STD (including vibration) was 11.151 deg/s and
  0.18868 g. Fixed throttle still permits translation: 18.31 m horizontal
  displacement and 3.90 m altitude loss; this is not position/altitude hold.
- Report: `test-output/stability-restored-noise.json`. Run library labels begin
  `Restored lab noise / 5 Hz`. Full reproducible preset:
  `HoverWorkbench/data/presets/restored-lab-noise-5Hz.json`.
- All 58 workbench tests and four calibration tests passed. One initial
  preset-parity failure identified the four shipped JSON examples still using
  threshold 48; regenerated them from their builders and reran that check.
  Model XML inspection confirmed the only block-parameter edits are the two
  requested noise-power expressions (plus MATLAB-generated save metadata).

## Fix plot navigation and add detachable views (2026-10-17)

- Reproduced the default/Home one-second limit with the saved 60 s hover.
  Removed cross-tab axis linking and explicitly saved full-run limits as the
  zoom baseline. Used the ruler LimitsChangedFcn so Home refreshes displayed
  samples as well as limits; XLim PostSet alone misses Restore View events.
- Default subtab loading and peak-preserving viewport rendering reduced
  initial displayed samples from 9,024,028 to 31,904 for that archive. Original
  samples remain available on close zoom, and saved data/CSV/workspace exports
  are unchanged. This is a rendered-point reduction, not a claimed runtime
  speedup factor. Ten zoom-in/out cycles including drawnow took 0.55 s locally.
- Added Full duration and Undock controls to Default/Explore, detached Flight
  analysis views, and a multiselect Remove signals dialog for Explore traces.
  Detached figures retain complete samples independently of the app.
- Seven plotting regression tests cover Home and its restored data, spikes,
  NaN gaps, exact detail on zoom, run-duration changes, independent detached
  figures, selective trace removal, and empty/single-sample data.
  All 44 tests in hoverWorkbenchTest, flightTestWorkflowTest and
  plotInteractionTest passed through MATLAB MCP. Inspected the default-tab
  screenshot and the separately exported detached estimated-state figure.
- Confirmed run.mat is already HDF5-backed v7.3. No archive migration, firmware,
  sensor, model, initialization-script or simulation-setting changes were made.
- Audited original pre-SITL noise blocks against the latest user-saved runs.
  Density/bias/vibration/bandwidth/sampling values are unchanged, but the
  previously approved white-noise power correction means actual white-noise
  RMS differs from the original: gyro about 10.85 -> 0.192 deg/s and accel
  about 0.174 -> 0.00435 g, before filtering. Native calibration/filter changes
  and 0.1-degree Euler output quantization also affect apparent estimator quality.

## Separate default plots and explain gyro noise (2026-10-16)

- Split attitude, angular rates, position and body velocity into individual
  plots for true and estimated state. Separate attitude/rate errors and controls
  into another tab; link the time axes and preserve every archived sample.
- Label native position/velocity estimates unavailable instead of showing the
  adapter's placeholder zeros. Legacy archives with real estimates still plot.
- Confirmed the original model's first-order gyro LPF used 5 Hz. The native
  example uses gyro LPF1 dynamic 250-500 Hz and LPF2 500 Hz; its displayed static
  LPF1 value of 250 Hz does not describe the entire active filter configuration.
  Only the accelerometer cutoff was changed to 5 Hz in the preceding fix.
- On the saved 60 s noisy hover, a 24 Hz least-squares fit to gyro measurement
  error over 20-60 s gives 3.700 deg/s at sensor input and 3.684 deg/s after
  native filtering. Applying the original 5 Hz recurrence offline to that same
  input gives 0.751 deg/s. This compares filter transmission, not two full-model
  simulations. The original and current wing gyro vibration amplitude is
  3.7 deg/s; earlier white-noise power corrections reduced raw white noise.
- Verified sample-for-sample plot data, units, archive switching between legacy
  and native channels, linked time zoom and the default-plot toggle through
  MATLAB MCP. No controller, filter, noise, initialization-script or model
  settings changed in this plot update.

## Fix inactive filter controls and vibration-induced attitude offset (2026-10-16)

- Found that the GUI still displayed the original 5 Hz LPF fields even though
  the native firmware used its independent 25 Hz accelerometer cutoff. Those
  legacy fields no longer controlled the estimator. Added an **Attitude
  estimator** page that edits the actual native cutoff/Kp/Ki and removed the
  inactive LPF widgets. Gains are displayed in physical units and stored with
  the correct native factor of 10000.
- A constrained, truly level native-firmware fixture with perfect gyro input
  develops a mean estimate of -0.116/+0.138 degrees under the shared 24 Hz,
  0.1 g three-axis vibration. A 5 Hz native cutoff eliminates that offset at
  the 0.1-degree telemetry resolution. Horizontal-only or vertical-only
  vibration also produces zero mean displayed tilt. This isolates the effect
  of correlated vibration passing through gravity-vector normalization.
- Changed all four complete examples to native `acc_lpf_hz=5`, estimator
  `imu_dcm_kp=2500` (0.25, the native/original proportional gain), and
  `imu_dcm_ki=0` (native default). Restored drag, rate PI gains, noise,
  vibration, throttle and optional PID-disable settings are preserved.
- Noisy 60 s hover finishes at +0.054/-0.020 degrees versus +0.175/-0.068
  before these filter/estimator-setting corrections. Recovery from +5/-3
  degrees finishes at -0.010/+0.001 degrees, entering +/-1 degree after
  0.874 s and +/-0.5 degree after 1.560 s.
- In the extended 180 s noisy run, peak absolute roll/pitch is 0.0866/0.0346
  degrees and the final attitude is +0.0557/-0.0086 degrees. The former growth
  is absent in this test; a small offset remains. Fixed-throttle translation
  and descent remain because these examples have no position/altitude hold.
- Tested estimator Ki=0.05 separately; it did not justify changing the native
  OFF default. No model-file, sensor-input or native firmware-code changes
  were required. The initialization script now explicitly identifies the
  legacy LPF fields as inactive in the Betaflight configuration.

## Restore original aerodynamic damping (2026-10-15)

- Restored CDx=CDy=CDz=CDw=1 from the pre-integration script at `4f2f207`.
  Removed the GUI's explicit zero-drag override and updated all four supplied
  example presets. Keeping drag disabled in the Betaflight examples was a mistake;
  the prior planning note attributing that preference to the user was unsupported.
- Verified both linear/nonlinear dynamics and the ideal accelerometer already
  use the corresponding drag forces. No model-file or firmware changes needed.
  PI gains, estimator tuning, throttle and sensor noise are unchanged.
- Noisy 60 s nonlinear hover ends at +0.175/-0.068 degrees, with 5.924 m
  horizontal displacement, compared with +0.295/-0.109 degrees and 25.945 m
  without drag. Recovery reaches +/-1 degree in 1.078 s. Full results and
  limitations are in VALIDATION.md; runs have **Drag restored** labels in the GUI.
- Added regression coverage for nonzero example damping and the physical
  steady-velocity limit in which the accelerometer recovers the gravity direction.
- Extended noisy hover to 180 s: true roll/pitch peak at 0.305/0.104 degrees
  and finish at +0.271/-0.077 degrees. The initial linear trend does not persist,
  but a nonzero attitude offset remains. A diagnostic removing only accel
  vibration changes the 60 s result to +0.092/+0.057 degrees, demonstrating
  a vibration-dependent offset. Stronger estimator correction alone does not
  remove it. Neither diagnostic changes the default settings.

## Estimator drift investigation and adapter fixes (2026-10-15, before drag restoration)

Two bugs were introduced in my Betaflight adapter: constant, noiseless startup
gyro samples produced a biased calibration for noisy flight samples, and the
host used rounded 16.4 gyro sensitivity rather than the driver's exact 16.384.
Both are corrected. Startup sends deterministic sensor-rate white noise with
the flight sensor's configured density/bandwidth. Native calibration, filters,
estimation and PID remain upstream algorithms. The noisy examples use 4 s
native calibration inside the existing 5 s supported warmup. Noise OFF remains
noise-free. Requested PI gains and disabled PID modifiers are unchanged.

Positive/negative supported roll/pitch and gyro-only roll/pitch/yaw tests rule
out the proposed sign reversal. Both model files remain unchanged. The only
initialization-script edit passes its existing noise seed into the adapter so
script and GUI initialization remain consistent. The native
adapter was rebuilt; its new binary hash and full results are in VALIDATION.md.

The corrected 60 s noisy level case ends at +0.295/-0.109 deg, compared with
-0.568/-0.969 deg before. Gyro offset error decreases from +0.0122 to about
-0.0021 deg/s. This is an improvement, not perfect attitude/position hold:
body-aligned thrust in the zero-drag, accelerating plant provides no independent
gravity direction for the accelerometer correction. Finite calibration error,
sensor noise/vibration and native quantization remain. No estimator sign was
flipped and no plant-truth feedback was added.

## Requested PI defaults (2026-10-15)

- Noisy hover and recovery now use **roll P/I/D/F = 133/4/0/0** and
  **pitch = 134/4/0/0**, converted from the original torque-based rate gains.
  The shared angle-pulse/rate-doublet examples inherit the same baseline;
  all four supplied JSON presets match their builders.
- Disabled optional native PID shaping, including I-term relax/rotation,
  anti-gravity, D-max, TPA, feedforward and its boosts, ANGLE feedforward/earth
  reference, throttle boost, thrust linearization and recovery assists.
  Native filters and integral/output limits remain. Unused settings without
  an OFF value retain their defaults; their parent feature/mode is inactive.
- The firmware CLI dump confirms the requested settings. Both noisy 10-second
  cases pass the existing flight criteria. Recovery reaches +/-1 degree in
  1.06 seconds, but residual attitude/position drift remains. A 60-second run
  ends at true roll/pitch -0.568/-0.969 degrees while the firmware reports level.
  Detailed metrics and saved-run locations are in VALIDATION.md.
- No changes to the model, initialization script, estimator implementation,
  native binary, script-default configuration or historical saved runs.
  An already-open app loads the new values via **Load complete example**.

## Flight-test workflow (2026-10-14)

- Added editable held command sequences and complete noisy angle-pulse and
  rate-doublet presets. The default level-hover case is unchanged. Commands
  still pass through native Betaflight receiver processing and control.
- Added Flight analysis: requested/true/estimated tracking, attitude error,
  native P/I/D/F terms, motor commands and raw gyro error, plus whole-run RMS
  metrics, saved-run selection and PNG/PDF export.
- Requested commands are saved as three additional named signals (107 total).
  Presets and data-only archives retain the exact command sequence.
- Corrected analysis-only altitude-rate conversion for tilted nonlinear
  flight, retaining zdot=w for the linearized plant. Normalized attitude
  errors now wrap at +/-180 degrees.
- No change to `lin_hover.m`, either `.slx` model, the native firmware binary,
  physical sensor equations or example PID gains in this continuation.

The original sensor formulation discussed below is consistent with supported
rest or stationary hover. The correction extends it to the accelerating
free-flight plant; it does not mean all original dynamics or hover results
were invalid. The mass/arm wiring had no numerical effect when both were 0.11.

## Which issues were pre-existing?

The source audit read the model from Git base commit `4f2f207` without running
or modifying that historical model. Its last model-file commit was `1146e6f`
(2026-10-03), before this Betaflight integration. That saved model contains:

| Issue | Evidence in the original model | Applied change |
|---|---|---|
| Free-flight accelerometer physics | `accel_gravity + noise_true*a_drag + noise_true*a_thrust` | Measure non-gravitational force/mass, matching linear/quadratic plant drag; physical force no longer depends on the noise switch |
| White-noise scaling | Band-Limited White Noise power was density squared times bandwidth, without multiplying by sample time | Set power to density squared times bandwidth times sample time |
| Nonlinear arm-length input | Constant3, SID 555, had `Value=m` | Use `S` |

The original mass and arm length were both numerically 0.11, which masked the
last wiring error until either parameter changed.

I introduced a compile error in the first version of the correction by passing
the text `sim_fidelity` into a numeric Stateflow parameter. This is fixed:
the script and workbench now derive the logical `imu_nonlinear` parameter.
Both plant variants compile and run. I also initially overlooked upstream
SITL's skipped virtual-gyro calibration when building the adapter; that
integration gap was fixed in the preceding continuation by enabling the
existing native calibration routine for this host build.

## Changes in this continuation

- Noise defaults **ON**, with a bold **Simulated noise: ON/OFF** toolbar checkbox
  visible from every page. It synchronizes with settings/presets and is locked
  during a simulation.
- Applied the explicitly approved model corrections above. Exposed sensor bias,
  noise density, vibration amplitude and sample rate in the GUI/init variables.
- Added ideal/measured accelerometer and gyro logging. Explore now includes
  104 scalar signals; raw sensor noise can be plotted separately from filtered
  attitude. No source scripts or model files are copied into run archives.
- Added an explicit **Ideal bench accel calibration** option. The example uses
  known simulated bias to prefill native integer offsets; it changes to zero
  offsets when noise is OFF. Disable it to retain manual CLI calibration.
  Requested settings and effective firmware settings are both saved; the latter
  are in `Variables.bfConfig`. This is an ideal calibration assumption, not a
  replacement estimator or an in-flight truth correction.
- Set the example's native `imu_dcm_kp` to 250 (0.025), from 2500 (0.25), to
  reduce accelerometer correction during thrust-driven motion. Rate PID gains
  remain P=10, I/D/F=0. No altitude sensor or altitude/position loop was added.
- Updated both complete JSON example presets and the flight/noise validation
  plots. Plot titles identify noise state and seed. Noise fixtures handle
  Simulink's time-last vector data correctly.

## Results and limits

For the default 10 s noisy nonlinear case (seed 23341), peak absolute roll/pitch
is 0.136/0.177 deg, horizontal displacement is 0.713 m and height loss is 0.293 m.
The noisy +5/-3 deg recovery enters and remains within 1 deg after 5.16 s,
finishing at 0.489/-0.580 deg. Position drifts because it is not controlled.
Both plants, noise on/off, an additional seed and the actual GUI run pass;
39 unit tests pass. The noise-OFF level run has exactly matching ideal/measured
IMU signals. Detailed metrics and criteria are in [VALIDATION.md](VALIDATION.md).
A new noisy Simulink trace, including ideal bench calibration and startup,
replays all 2,632 firmware exchanges exactly in a fresh process.

Remaining limitations include zero default yaw authority, common-axis
vibration/correlated random noise inherited from the sensor model, ideal
pre-release calibration, quantized fixed-throttle trim, and the hardware/SITL
coverage boundaries documented in [README.md](README.md).
