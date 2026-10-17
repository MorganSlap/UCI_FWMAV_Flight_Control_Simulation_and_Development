# Betaflight flight stack in the hover simulation

This branch runs the **actual Betaflight SITL firmware** in its own process,
connected to `bf_flight_controller.slx`. The top-level `lin_hover_sim.slx`
retains the linear/nonlinear plant structure, wing actuator model and plotting
outputs, with the approved sensor-physics and moment-arm corrections below.
The firmware replaces the old controller,
estimator and mixer. Mixer execution follows the firmware PID task.

The source is pinned to upstream commit
`c78d9e7bd24ef60f4324dffde11df26c53d4f29f` (2026.12.0-alpha).
This is a development revision of [Betaflight](https://github.com/betaflight/betaflight),
not a moving download of whatever `master` happens to contain later.

## Open and run

From the repository root in MATLAB:

```matlab
addpath('Betaflight','1_Hover Simulation Work');
app = hoverWorkbench;
```

The app opens with the **IMU-only trimmed hover** example filled in:
10 seconds, nonlinear plant, level initial attitude, zero angle reference,
sensor noise **on** (seed 23341), native ANGLE mode, 1859 us fixed receiver throttle, and
one second of throttle settling before releasing the airborne plant. No
altitude sensor, altitude controller, GPS or magnetometer is used. True
position/height are available only for analysis. **Load hover example** restores
this case; **Reset to script defaults** restores the script inputs. The prominent
**Simulated noise: ON/OFF** checkbox beside Run is available from every page.
It stays synchronized with loaded presets and the Simulation settings page,
and is disabled during a run. The seed and noise parameters are saved.

The original **CDx=CDy=CDz=CDw=1** aerodynamic damping is enabled in the script,
GUI defaults and all four complete examples. Edit it under **Aerodynamic damping**.
The nonlinear plant and ideal IMU both use the same quadratic drag forces;
the linear plant and IMU use the same linearized drag coefficients. The earlier
GUI override that set all four coefficients to zero has been removed.

Two complete, data-only presets are in `Betaflight/presets/`:
`imu-only-hover.json` and `attitude-recovery.json`. The recovery case starts at
+5 degrees roll / -3 degrees pitch with otherwise identical settings. Use
**Load preset** to select it. These are attitude-control examples at fixed
throttle; they do not establish position/altitude hold. Measured results for
the current gains and earlier presets are distinguished in [VALIDATION.md](VALIDATION.md).

Simulation defaults and all four supplied examples now use **gyro LPF1 PT1 at
5 Hz**, with simplified gyro tuning OFF, dynamic LPF minimum 0 (disabled) and
LPF2 0 (disabled). The accelerometer uses **native PT2 at 5 Hz**. This applies
to new `bf.hoverConfig` configurations from either the script or the workbench;
saved user presets and archived settings retain their original values.

The examples use native **`acc_lpf_hz = 5`**, **`imu_dcm_kp = 2500` (0.25)** and
**`imu_dcm_ki = 0`**. The 5 Hz cutoff rejects the simulated 24 Hz wing vibration;
the earlier 25 Hz cutoff allowed correlated vibration to bias the estimated
gravity direction. The proportional correction is restored to the native
default and the original script's 0.25. Integral attitude-bias correction stays
at the native default OFF. The original torque-based rate PI gains are converted
to native integer settings:

| Axis | P | I | D | F |
|---|---:|---:|---:|---:|
| Roll | 133 | 4 | 0 | 0 |
| Pitch | 134 | 4 | 0 | 0 |
| Yaw (no plant authority) | 0 | 0 | 0 | 0 |

The conversion uses arm length 0.11 m, thrust slope 0.000458 N/command,
and the native 1055--1950 output range: one PID-sum unit corresponds to
`2*S*C11*(1950-1055)/1000 = 9.01802e-5` Nm. Native P/I scaling and the
rad/s-to-deg/s conversion give unrounded roll P/I 132.9369/3.9598 and pitch
133.6221/3.9802. This matches small unsaturated rate-loop gains; it does not
make the complete filtered ANGLE loop identical to the original controller.
Reconvert after changing the actuator range, mixer or physical parameters.

I-term relax/rotation, anti-gravity, D-max, both TPA rates, rate/ANGLE
feedforward, feedforward boost/yaw hold, ANGLE earth reference, throttle boost,
thrust linearization, battery sag compensation, rate acceleration limiting,
crash recovery and yaw-spin recovery are disabled. Simplified PID tuning is
OFF so sliders cannot rewrite the gains. TPA has no OFF enum: both rates are
zero, while its mode remains the native default D. Unused smoothing times,
thresholds, launch-control and HORIZON parameters retain native defaults;
launch/HORIZON modes are not assigned to AUX channels. Integral/output clamps,
sensor filtering, receiver smoothing, arming/failsafe and the existing ANGLE
P gain of 20 remain in place.

**Settings > Attitude estimator** exposes the active native accelerometer
cutoff and estimator Kp/Ki. Gains are displayed directly (0.25 means native
`imu_dcm_kp=2500`); saved presets and runs retain the actual CLI values. The
inactive legacy `accel.LPF_set` and `gyro.LPF_set` controls are removed from
the GUI. Those fields remain in old settings for compatibility but do not
configure the native filters. Use Betaflight Configurator for gyro filters.

The shared ANGLE-pulse/RATE-doublet examples inherit the same PI baseline.
The script's separate `bf.hoverConfig()` baseline is unchanged; saved historical
runs and user-created presets retain their original settings. Load a complete
example (or the updated JSON preset) to apply these values in an already-open app.

**Ideal bench accel calibration** is explicitly enabled in Firmware interface:
it uses the known simulated bias to populate native `acc_calibration` before
startup, without feeding true attitude/position into the estimator. Offsets are
[-5,-5,-5] counts with noise on and [0,0,0] with noise off. This is an ideal
bench-calibration assumption, not a simulated noisy calibration procedure.
Disable it to use manually entered CLI offsets unchanged. The effective
firmware configuration is saved in `Variables.bfConfig` in each run.

The 1859 us pulse was selected from measured native firmware output, including
its integer receiver/throttle processing. Its mean motor command is
1815.748657 versus the plant's ideal 1816.102620. That small thrust deficit
explains the remaining descent. Re-trim after changing physical parameters,
throttle curves or motor settings; increasing the pulse to 1860 reverses
the mismatch rather than producing an exact equilibrium.

Use **Betaflight Configurator** in the Settings sidebar to edit native PID,
feedforward, filters, profiles, rates, modes and mixer values. Press **Apply**
to transfer edits to the workbench, then **Run simulation**. The standalone
editor is also available:

```matlab
bfConfig = bf.hoverConfig();
editor = betaflightConfigurator(bfConfig);
```

The catalog contains every `set` setting exposed by this compiled target,
including its allowed values and profile scope. Receiver, mode, custom mixer,
feature and other command families remain editable in the corresponding CLI
tabs. The firmware's own CLI parser validates the complete configuration when
a run starts. The GUI does not flash or connect to a physical flight controller.

To use the original script, run `1_Hover Simulation Work/lin_hover.m`.
It preserves an existing workspace `bfConfig`; otherwise it creates the hover
preset. Legacy PID/Mahony variables are retained for comparisons with older
runs and no longer configure the flight software. All native firmware settings
are in `bfConfig.CLI`, with a searchable schema in `bfConfig.SchemaText`.

The workbench **Firmware interface** page sets ANGLE versus rate references,
receiver frame rate, startup timing, throttle and native PID/mixer frequency.
The model's `Xref` input uses:

| Command mode | Command used |
|---|---|
| `angle` | `Xref(7:8)` roll/pitch angles in radians; `Xref(12)` yaw rate |
| `rate` | `Xref(10:12)` body rates in rad/s |
| `receiver` | Raw 16-channel `bfRc` pulses in microseconds |

For angle/rate references, the host inverts the *actual firmware rate function*
to generate receiver pulses. Native receiver smoothing, rate limits and mode
processing still execute. Integer receiver pulses introduce normal input
quantization. Position/velocity entries in Xref are not ANGLE-mode commands.

The **Receiver channels** page edits all 16 physical input pulses, with separate
calibration/disarmed and armed/simulation columns. These values are saved in
presets and run archives. Automatic values honor the firmware `map`, `rxrange`,
`mid_rc` and first ARM/ANGLE AUX ranges. Use custom pulses for multiple AND/OR
conditions and linked modes; the actual firmware evaluates that logic.
Restore automatic values with the button below the table. Arming settle uses
the simulation column with throttle held at the calibrated minimum.

For time-varying receiver trajectories, connect a 16-channel source to the
receiver input. Startup requires an ARM AUX range. The adapter checks that
calibration remains disarmed, arming succeeds, and the actual ANGLE/rate mode
agrees with the selected reference type. Raw receiver mode allows other native
flight modes, such as HORIZON, to be selected through AUX pulses.

## Configuration and data

### Repeatable tuning runs

Open **Settings > Run setup** to load a complete noisy hover, recovery,
ANGLE-pulse or RATE-doublet example. Loading a complete example replaces the
current plant, firmware and interface settings. The hover example remains the
startup default. The command table can then be edited independently of the PID
gains: rows contain time, roll, pitch and yaw rate. In ANGLE mode roll/pitch
are degrees; in RATE mode they are degrees/second. Time starts at plant release
after calibration, arming and throttle settling. Rows hold until the next row;
before the first row the model's Xref applies. **Use constant Xref** clears the
sequence. Rows beyond the stop time are not executed. Raw receiver mode requires
an empty sequence; its physical input channels remain the source of commands.

The sequence is applied in the physical-reference adapter before native receiver
processing. It does not bypass Betaflight rate conversion, quantization,
smoothing, limits, ANGLE control, PID or the mixer. Changes are accepted at the
receiver frame rate. In script use, optional `bfSim.ReferenceSchedule` rows are
`[seconds, roll, pitch, yawRate]`, in radians / radians per second, not the GUI's
degrees. An empty sequence preserves the reference input without modification.

**Flight analysis** displays a saved run's requested/true/estimated tracking,
attitude estimation error, native P/I/D/feedforward contributions, all four
motor commands and measured-minus-ideal gyro signal. Select Roll, Pitch or Yaw
and export the six plots as PNG or PDF. RMS values cover the entire recorded
interval and are weighted by elapsed time. They describe the run, not an
automatic pass/fail assessment or a settled tracking error.

Requested commands also appear in **Explore > Requested commands**, saved with
their units and reconstructed from the workbench's constant Xref and saved
sequence. They precede receiver processing and are not the internal ANGLE-loop
rate setpoint. New workbench runs normally have 107 scalar signals. Older
archives still load, with command reconstruction for analysis where possible;
missing raw IMU logs are identified. For a custom model with another varying
reference source, log that source directly rather than relying on this
workbench-specific reconstruction.

Changing the displayed run never changes the current settings. Use the existing
**Use this run's settings** action to restore a tuning configuration. Archives
remain settings, data and lightweight metadata only.

* **Save preset** saves plant settings, firmware CLI/schema/identity, interface
  overrides and display preferences as JSON. **Load preset** restores them.
* The configurator independently saves JSON or exports/imports CLI text.
* Each workbench run contains `run.mat`, `settings.json` and `metadata.json`.
  They contain settings, numeric data, normalized signals, original
  SimulationOutput and small provenance records. Model files and source
  scripts are **not copied into run archives**.
* Firmware identity and the executed binary's SHA-256 are recorded. The local
  `Betaflight/runtime` folders contain process logs and EEPROM files useful
  for diagnosing startup; they are ignored by Git.
* Existing default plots remain available. Explore includes state, controls,
  estimate and firmware diagnostics; double-click overlays/replaces/adds a
  plot according to the selected plot mode. Workspace and CSV export remain
  available for custom analysis.

## Interface contract

The plant state is `[N E D u v w phi theta psi p q r]`, SI units, body FRD.
Gyroscope input is body `[p q r]` in rad/s. Accelerometer input is specific
force in m/s², with `[0 0 -g]` at level rest. Virtual sensor counts use the
upstream SITL sensitivities; the host does not inject a truth quaternion into
the estimator. Stationary startup uses gravity at the initial roll/pitch.
Absolute heading is unobservable from accelerometer/gyro alone.

This host build enables Betaflight's original gyro calibration routine for
the virtual sensor. Unmodified upstream SITL bypasses it and therefore leaves
simulated gyro bias uncompensated. The host-specific preprocessor change does
not replace the calibration algorithm. The stationary warmup receives the
configured sensor bias, followed by arming and throttle settling. Accelerometer
offset correction remains the native `acc_calibration` setting; the optional
ideal bench calibration above supplies its values. These are simulated pre-release phases, not a
takeoff or ground-contact model.

Startup now supplies gyro white noise at the configured physical sensor rate,
using a local deterministic random stream and the same noise density/bandwidth
as the flight sensor. The seed is saved with the run. Firmware still performs
its own ADC quantization, offset averaging and movement check. This corrects
the earlier adapter's constant-bias calibration: quantizing one constant value
does not reproduce the mean of noisy, quantized flight samples. Receiver frames
continue at their configured rate while IMU samples arrive at 4 kHz.
The examples set `gyro_calib_duration = 400` (4 s), within their 5 s supported
warmup; increase warmup if requesting a longer calibration. Noise OFF also
disables calibration noise. Startup assumes a quiet supported IMU, with no
wing vibration; accelerometer startup remains the ideal bench fixture above.

The gyro boundary uses the driver's exact sensitivity (16.384 counts per
degree/second in this build), replacing the earlier rounded 16.4 conversion.
Neither change modifies native Mahony/PID code or feeds true attitude back
into it. See [VALIDATION.md](VALIDATION.md) for direct sign tests and drift runs.

As a limiting case, with zero translational drag, free-flight thrust is body-aligned and the
accelerometer measures `[0,0,-T/m]` even when the vehicle is tilted and
accelerating. It cannot separate gravity from translational acceleration.
The native Mahony gravity assumption therefore pulls its estimate toward
apparent level, and finite gyro-calibration error can still produce real
attitude drift. Integer accel-offset quantization and vibration contribute as
well. Better rate gains cannot recover an unobserved true tilt. This simulator
does not use plant truth as an artificial gravity measurement.

Drag is enabled by default. It contributes lateral specific force while
opposing translation. Once translational acceleration is small, measured
specific force approaches negative gravity in body coordinates, providing
roll/pitch information. During acceleration, a gravity-only interpretation
still has transient errors. Restoring drag does not imply position hold or
identical behavior to the original estimator/controller.

Native gyro/controller body-axis signs match these FRD rate inputs. For the
Mahony estimator path used here, roll/pitch Euler outputs have the same signs;
the firmware heading sign is reversed and wrapped to ±pi at the boundary.
These conventions are tested together with stationary combined-axis tilt.

Physical actuator order is **front, right, rear, left**. The preset uses native
CUSTOM mixing with roll `[0 -1 0 1]`, pitch `[1 0 -1 0]` and yaw
`[-1 1 -1 1]`; Betaflight's native yaw mixer sign supplies the plant's yaw
pattern. Absolute motor PWM minus `u0` becomes the existing delta-pot input.
The actuator block still supplies wing dynamics before the plant.

The build's gyro loop and Simulink sensor interface run at **4 kHz**; keep
`fs=4000` and `Ts=1/4000`. The firmware independently runs PID and mixing at
`4000 / pid_process_denom` Hz (dividers 1–16). `bfSim.PidSampleTime` records
that period. Changing the PID divider does not reduce sensor sampling or
change the plant's sensor filter coefficients. Native tasks are
dispatched against simulated time in 10 µs increments, with held samples
between exchanges. Startup calibrates disarmed, raises the configured ARM AUX
channel, checks arming and then releases the plant. Each run gets a new process
so firmware static state does not leak between runs.

The supplied slow-wing starting preset uses P=10, I/D/F=0 on roll/pitch and
Anti Gravity gain=0. Anti Gravity adds a separate I-term gain during throttle
changes, including when the configured I gain is zero; leaving its quadrotor
default enabled caused a persistent startup offset on this plant. All of these
remain editable native firmware settings. This preset is a simulation starting
point, not a tuned configuration for physical flight.

Automatic hover throttle calculation approximately inverts PWM idle/max endpoints
and the preset's linear throttle curve; native integer arithmetic means it is
not an exact trim. The example overrides it with the measured 1859 us pulse.
After changing throttle expo, motor output
limit, thrust linearization or 3D settings, set the receiver pulse explicitly
in **Firmware interface**. It is a receiver command, not an altitude controller.

## Fidelity boundaries

The enabled SITL flight stack includes upstream receiver processing, arming,
failsafe, filters, Mahony attitude estimation, PID/feedforward, modes and motor
mixing. Firmware code implements these algorithms; there is no MATLAB PID
approximation. Native floating-point calculations and the host compiler are
not asserted to be bit-identical to every MCU build.

This is **not a complete emulation of every Betaflight hardware target**.
Upstream SITL explicitly excludes physical serial receiver protocols, OSD,
VTX control, LED strip, ADC, SPI/I²C and several hardware telemetry drivers.
The adapter models no CPU execution cost, interrupt contention or ESC wire
protocol timing, and supplies no measured motor RPM telemetry. Hardware-only
features and RPM-dependent behavior cannot be claimed verified by these runs.
Normal Simulink mode is required; accelerator, rapid accelerator and generated
embedded code are not supported by the process/TCP boundary.

The default transport uses Java's standard socket/channel classes bundled with
MATLAB, with TCP_NODELAY, fixed-size binary messages and a socket read timeout.
The original MATLAB `tcpclient` transport remains available as
`bf.Client(config,5,'matlab')` for comparison. Cross-transport replay is checked
for exact equality by `bf.verifyHost`; only communication overhead changes.

Ideal navigation feed flags exist in the host protocol but default to zero;
navigation/rescue/position-hold behavior is not validated by the hover checks.
The GUI shows the compiled target's settings, not settings fabricated for
disabled hardware features.

The existing plant still has zero yaw authority by default and hard-codes zero
yaw torque in the nonlinear equations. It does not establish real-aircraft
tuning. The retained vibration is common across axes, and the original shared
white-noise seed is retained, so axis noise is correlated. Native sensor LPFs
run in the firmware; the legacy script's `accel/gyro.LPF_set` values do not
configure those native filters.

With explicit user approval, `bf.upgradeFlightInterfaces` has been applied:
the IMU now measures non-gravitational force/mass, selects matching linear or
quadratic drag, and retains physical acceleration when noise is off. On
2026-10-17 the user requested restoring the lab-matched white-noise power:
density squared times bandwidth, without the sample-time factor. The block
therefore produces sample variance equal to that power divided by sample time.
Startup gyro noise matches that convention; noisy example calibration uses
`gyro_calib_noise_limit=200`. Bias, noise density, vibration amplitude and
output rate are configurable. The nonlinear moment-arm input now uses `S`.
`bf.flightInterfacesReady` returns true; the sensor editors are enabled.

`bf.enableImuLogging` records ideal/measured accelerometer and gyro vectors in
`logsout`. Explore includes named raw gyro/accelerometer groups in SI and display
units, in addition to the original logs. `bf.plotImuNoise(record.Output,record.Variables)` plots sensor error
and a final-half-second detail, so filtered attitude plots cannot hide whether
noise was enabled. Run archives still contain only settings, data and metadata.

## Build on Windows

The executable already built locally lives under ignored `Betaflight/build`.
For a fresh checkout, in PowerShell from the repository root:

```powershell
./Betaflight/build-host.ps1 -InstallToolchain
```

This downloads an isolated Cygwin toolchain under `Betaflight/toolchain`, without
administrator installation, registry registration, shortcuts or system PATH
changes. It pins GCC 13.5.0 and verifies that package's SHA-512. Git fetches the
pinned upstream revision and the required pinned submodules. Later rebuilds:

```powershell
./Betaflight/build-host.ps1
```

The build copy is `/build/betaflight` inside Cygwin to avoid GNU make paths with
spaces. `host/apply-host-patches.ps1` applies explicit host hooks. Windows PE
linking replaces `.fini_array` insertion with `.data` and removes ELF's
`-z noexecstack`. Serial `make -j1` avoids the observed Cygwin LTO jobserver
failure. Build output is `toolchain/cygwin/build/host-build.log`.
The complete upstream source and GPL license remain available locally; the
host additions are GPL-3.0-or-later. See `host/LICENSE` and `host/PROTOCOL.md`.

## Verification

```matlab
addpath('Betaflight');
results = runtests('Betaflight/+bf/configurationTest.m');
hostReport = bf.verifyHost;
estimatorReport = bf.verifyEstimator; % gyro bias, dynamic attitude, no truth feed
[report,record,fig] = bf.verifyHover('level','high');
[report,record,fig] = bf.verifyHover('recovery','high');
[report,record,fig] = bf.verifyHover('level','low');
[report,record,fig] = bf.verifyHover('level','high',false); % noise off
timingReport = bf.verifyTiming;       % all 16 dividers, all five rate curves
modeReport = bf.verifyModes;          % AND arming, ANGLE/HORIZON, linked modes
replayReport = bf.verifyPlantReplay;  % both plants at 4 kHz gyro / 1 kHz PID
[flightReport,record] = bf.verifyFlightTest('angle','high',true); % full trace/replay
[rateReport,record] = bf.verifyFlightTest('rate','high');
check = bf.PlantCheck('high',10);  % nonblocking; inspect check.Status
% After it finishes, run the other plant:
checkLinear = bf.PlantCheck('low',10);
```

The configuration tests cover profile edits, JSON/CLI round trips, constraints,
actual battery-profile metadata, receiver mapping/endpoints and custom startup
pulses. Host checks
exercise calibration, arming, combined-axis tilt, rate/gyro/motor signs,
repeatability, PID/FF gain effects and lost-receiver failsafe. Plant checks
verify output dimensions, finite data, native loop rate, arming, motor limits,
bounded hover attitude and data/settings reload. JSON reports and archived
runs are written to ignored `Betaflight/test-output` as each check completes.
Run plant checks sequentially. The interpreted TCP bridge is substantially
slower than real time; reported wall times include startup and compilation.

To capture a complete firmware exchange history for a specific diagnostic run,
set `bfSim.TraceFile` (script) or `settings.FirmwareAdapter.TraceFile` (workbench)
to a new `.bin` filename. Logging is off by default. The numeric trace and small
configuration `.mat` sidecar include calibration and every subsequent exchange;
no script or model is copied. After the run:

```matlab
report = bf.replayTrace('path/to/new-trace.bin');
```

Replay starts a fresh process using the saved settings and checks exact equality
of every response word, including estimator, PID, motors and scheduler ticks.
It requires the same binary SHA-256. Existing traces are never overwritten.
