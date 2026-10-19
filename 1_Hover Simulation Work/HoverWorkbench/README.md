# Hover Workbench

A settings, simulation, and analysis app for `lin_hover_sim.slx`, built with MATLAB App Designer components. It reads the same initial values as `lin_hover.m` and independently calculates the variables needed by the model.

On `codex/betaflight-simulation`, the model runs actual Betaflight SITL firmware.
Use the **Betaflight Configurator** button for native flight software settings
and **Firmware interface** for receiver/startup settings and PID/mixer frequency.
**Receiver channels** provides separate calibration and simulation pulse tables
for all 16 input channels, including custom AUX combinations. Sensor sampling
stays at 4 kHz when the native PID/mixer divider changes. See
[the integration guide](../../Betaflight/README.md) for build instructions,
parameter mapping, verification and supported-feature boundaries. Presets and
run archives include the firmware configuration; legacy PID/Mahony/mixer fields
are retained in old records but do not control the new firmware.

**Aerodynamic damping** retains the original script's CDx=CDy=CDz=CDw=1.
These values are also in all four complete examples and supplied JSON presets.
Loading a historical run or user-saved preset restores its saved drag values;
old zero-drag archives are not rewritten.

Simulation defaults and all four complete examples use **gyro LPF1 PT1 at
5 Hz**, with simplified gyro tuning OFF, dynamic minimum 0 (disabled), and
LPF2 0 (disabled). The **accelerometer uses native PT2 at 5 Hz**. These defaults
also apply when the initialization script creates a new `bf.hoverConfig`.
Previously saved user presets and run settings retain their saved filters.

**Attitude estimator** edits the actual native accelerometer filter and
Mahony gains. The examples use Kp=0.25 and Ki=0.
Physical gains are converted to/from the native CLI's factor of 10000. The
former `accel.LPF_set`/`gyro.LPF_set` widgets were inactive after the firmware
replacement and are removed; gyro filters are configured in Betaflight
Configurator. No sensor noise or vibration is disabled by this change.

**Default plots** separates attitude, angular rates, position and body velocity
into four axes under **True state**, with the same four panels under
**Estimated state**. **Errors and controls** contains separate attitude/rate
errors and motor commands. Each plot zooms independently. **Home** and
**Full duration** restore the loaded run's full time range. Only the selected
default subtab is rendered on load. Broad views show a peak-preserving subset
of the original samples; zooming into a short interval reveals every sample.
This changes display density only: archives and CSV/workspace exports retain
the complete signals. Position displays altitude=-z, while body velocity
displays u/v/w with w positive down. Native position/velocity estimates are
marked unavailable because the adapter reserves those channels as zeros;
historical runs with actual estimates still display them.

**Undock this view** opens the current default group in a separate MATLAB
figure. Explore has **Undock plot**, and Flight analysis has **Undock plots**.
These are independent snapshots with full underlying samples: they remain
usable after changing the selected run or closing the app. Explore's
**Remove signals...** opens a multiselect list of traces in the active plot,
including overlays from different runs; **Clear plot** removes all traces.

Run files already use MATLAB `-v7.3`, an HDF5-based format. The current nested
record is loaded as a whole. A future dataset-per-signal layout could support
partial loading for very large archives, but changing to an `.h5` extension
alone would not make plot interaction faster.

The app has four pages: **Settings**, **Default plots**, **Explore runs**, and
**Flight analysis**.
The `.mlapp` contains the App Designer shell; dynamic parameter editors and
behavior are maintained in `HoverWorkbenchController.m`, and calculations,
storage, and plotting helpers are in `+hover`.

## Open the app

Use MATLAB R2025b with Simulink and the products required by the existing model. In MATLAB, change to `1_Hover Simulation Work` and run:

```matlab
hoverWorkbench
```

The launcher adds the workbench folder to the path and opens `HoverWorkbench.mlapp`. The app must remain beside its `+hover` package and controller class.

## Settings and presets

The settings pages expose the script's active vehicle, damping, controller, sensor, estimator, noise, initial-state, reference, and simulation inputs. Units are shown beside fields. Derived values, such as the controller sample time, sensor filter coefficients, trim throttle, and state-space matrices, are calculated from the current inputs rather than entered separately.

Save a preset to keep a configuration without running a simulation. Presets are versioned JSON files, and loading them restores the saved inputs and default-plot option. A run also stores its own copy of the settings, so editing or replacing a preset later does not change historical runs.

The state order is `[x y z u v w phi theta psi p q r]`. Initial-condition and reference tables show angles in **degrees** and body rates in **degrees per second**, with the value column beside the state names. Aerodynamic reference rates also use degrees per second. Positions use metres and translational velocities use metres per second. The UI converts angular entries to radians/radians per second before storing them in settings and passing them to the simulation. Existing presets and run archives retain their SI format and display correctly when loaded. The body/NED vertical direction is positive down. Signal exports retain the units shown by the signal browser.

**Settings > PID** groups the native Roll/Pitch/Yaw P, I, D and Feedforward gains, with **ANGLE mode P gain** in a separate attitude-control section. The profile selector chooses the native PID profile for the next run. ANGLE P edits `angle_p_gain`, which controls the outer roll/pitch attitude loop in ANGLE mode and is separate from rate-controller P and estimator Kp. Changes synchronize with the Configurator and are saved with presets and runs. The page also exposes simplified PID tuning: OFF retains manual gains, while enabled modes can recalculate them. Full firmware settings remain available in Betaflight Configurator.

The plant's noise switch is preserved. Betaflight estimator gains are configured
through its native `imu_dcm_kp` and `imu_dcm_ki` settings; legacy Mahoney fields
do not configure this branch's estimator.

## Run and retain results

Choose a run label, review the settings, and run the simulation. Each completed run is automatically saved in the selected results library. A separate folder is created for each run; labels can be reused without overwriting previous data.

The default library is `HoverWorkbench/data/` (ignored by Git). Use **Storage
folder...** on Explore runs to select a different library. **Stop** retains
partial results and marks the run as stopped. Simulink runs through its native
asynchronous Simulation API; compilation and archival can briefly occupy MATLAB.
The app requires saving any existing unsaved model edits before a run, so the
recorded source hashes identify the model being simulated.

```text
results-library/
  <UTC-timestamp>_<unique-id>/
    settings.json     # Portable input preset
    metadata.json     # Small searchable run summary and provenance
    run.mat           # Raw output, signals, settings, derived variables
```

`run.mat` contains one structure named `record`:

| Field | Contents |
| --- | --- |
| `Settings` | Exact input settings used for the run |
| `Variables` | Calculated model variables, including matrices and effective gains |
| `Output` | Original simulation output |
| `Signals` | Named scalar time series with time, data, units, group, and source |
| `Metadata` | Run label, notes, status, source paths and source hashes |
| `ID`, `Created` | Unique identifier and UTC creation time |

The archive is written to a staging folder and then finalized. Incomplete staging folders are not shown in the run library. A results library can be moved or copied; use the library folder selector to reopen it. New archives contain settings, simulation data, and lightweight metadata. The model and initialization script are not copied into run folders. Existing archives remain readable, and any source copies in older archives are left in place. Keep libraries outside source control when they contain large simulation files.

## Default and custom plots

On the Betaflight branch the app opens with a complete **IMU-only trimmed
hover** example: 10 s, level initial state, noise ON, ANGLE mode and 1859 us
fixed throttle. **Load hover example** restores it. No altitude sensor or
altitude/position controller is added. The saved `Betaflight/presets` JSON files
include this case and a +5/-3 degree attitude-recovery case. **Reset to script
defaults** remains available for the script inputs. The toolbar's bold
**Simulated noise: ON/OFF** checkbox works on every page and synchronizes with
presets and the Simulation page. Ideal and measured accelerometer/gyro signals
are available in Explore; requested commands bring new normal runs to 107 signals. The example
enables ideal bench accelerometer calibration from known simulated bias; disable
that option in Firmware interface to use manual native calibration offsets.
See `Betaflight/VALIDATION.md` for measured drift and the applied sensor-model fixes.

The noisy examples use converted native rate gains **roll P/I/D = 133/4/0**
and **pitch = 134/4/0**, with feedforward zero and optional PID modifiers
(including I-term relax, anti-gravity, D-max and TPA) disabled. Native sensor
filters and integral/output limits remain. ANGLE/rate sequence examples share
this baseline. The script defaults and previously saved runs/presets are separate;
use **Load complete example** to refresh an already-open app.

The noisy examples use **4 s native gyro calibration** inside the 5 s supported
warmup. Startup gyro samples include the configured white noise before native
ADC quantization, with the saved seed. This fixes a constant-startup/noisy-flight
calibration mismatch. The rebuilt host also uses the native driver's exact
gyro scale. Both changes preserve the sensor axis signs and flight algorithms;
finite calibration error and accelerating-flight attitude-estimation limits
remain. Saved comparisons are in the run library under **Estimator fix**.

**Settings > Run setup** adds complete noisy hover/recovery examples, 3-degree
angle pulses and +/-15 degree/second rate doublets. Loading an example replaces
the current settings; afterward, edit command times and magnitudes in the table
without changing the PID gains. Times start at airborne plant release. Commands
hold until the next row and are consumed at the native receiver rate. Empty
sequences use the existing Xref. GUI angles use degrees; saved adapter sequences
use radians. Throttle remains fixed, and yaw authority is zero in this plant.

**Flight analysis** uses the selected run's saved settings and signals. Select
Roll, Pitch or Yaw; each panel now explains its inputs and units:

| Panel | What it analyzes |
| --- | --- |
| Command and response | Requested command, true plant response and firmware feedback. ANGLE roll/pitch use degrees; rate mode and yaw use degrees/second. Requested commands precede native receiver shaping. Raw receiver mode uses the logged native receiver rate when available. |
| Angular rate feedback / attitude estimate | The complementary view: true body rate versus filtered gyro during ANGLE roll/pitch tests, or true versus estimated attitude during rate/yaw tests. |
| Attitude estimation error | Wrapped true angle minus estimated angle; zero means an accurate estimate. |
| Rate-controller contributions | Native P, I, D, feedforward and sum before motor mixing; these are firmware PID units, not torque. |
| Actuator outputs after mixing | All four motor commands, regardless of the selected axis, with the plant's hover trim as a dashed reference. |
| Raw gyro measurement error | Measured minus ideal gyro for the selected axis, before firmware filtering/calibration. Includes bias, white noise, vibration and sampling effects. |

Whole-run tracking RMS compares truth with the plotted command; estimator RMS
compares true and estimated angle. Both include startup/command transients.
Missing historical logs get an explicit message in the relevant panel.
Export all six panels as PNG/PDF or undock them with their explanations intact.
Requested commands also remain available for custom plots in Explore.

For new runs, derived altitude rate follows each plant's position equation:
body-to-NED velocity for the nonlinear plant, and -w for the linearized plant.
Normalized angular estimation errors wrap at +/-180 degrees. Historical saved
data is not rewritten when the app is updated.

Default plotting can be enabled or disabled independently of saving results. Attitude, angular rates, position and velocity each have their own axes, arranged in True state, Estimated state, and Errors and controls views. Truth is interpolated onto estimator timestamps for the error plots.

Open a saved run in the signal browser and double-click a signal to plot it. Overlay signals on the selected plot or create another plot. Load additional runs to compare the same quantities across settings. Signals retain their own timestamps; custom plotting does not require a shared sampling grid. Use the app's export actions to work with the data in the MATLAB workspace, save CSV data, or export a figure.

The plot mode offers **Overlay on active plot**, **Replace active plot**, or
**Create a new plot**. Select multiple tree leaves and choose **Plot selected
signals** to add a group at once. Mixed units are allowed and identified on the
axis; use separate plots for different scales. **To workspace** exports the full
record as `hoverRun` and selected MATLAB `timeseries` objects as fields of
`hoverSignals`. **Export signal CSV** writes each selected signal on its own time
grid. **Use this run's settings** restores inputs from the selected historical
run. Default plots can be selected independently with the run dropdown.

Existing To Workspace outputs and compatible `logsout` signals are captured.
The app does not automatically log every internal wire; additional signals marked
for logging in Simulink appear in the browser after the next run. No model solver,
Scope, controller, or plant blocks are changed by the app.

Controls are provided both as the raw `control.delta1` through `control.delta4` outputs and the script-equivalent `control.pot1` through `control.pot4` values, which add the run's own `u0` trim. The library also includes altitude, altitude rate, attitude/rate errors, and any compatible signals already present in `logsout`.

## Analyze saved data from MATLAB

### Run setup and sensors

**Run setup** is the first settings page: complete flight case, duration,
linear/nonlinear fidelity, noise/seed, drag enable, mode, throttle and command
sequence are together. Initial conditions and constant references retain their
own pages. Time-constant damping is no longer editable in the app; app runs use
reference-speed drag. **Enable aerodynamic drag** sets all four effective run
coefficients (`CDx/CDy/CDz/CDw`) to zero when off and retains the entered values
for re-enabling. Saved run Variables contain the effective values.

**Sensors and estimator** contains separate gyroscope and accelerometer panels.
The gyro controls edit native LPF settings; dynamic minimum zero disables the
dynamic filter so the static cutoff applies. The accelerometer cutoff controls
the native PT2, not the legacy script's PT1 coefficient.

**Raw gyroscope** and **Raw accelerometer** groups in Explore expose X/Y/Z before
firmware calibration and digital filtering, in rad/s and deg/s, or m/s² and g.
These include the physical sensor model's bandwidth, sampling, quantization,
bias, vibration and white noise. Existing archives with IMU logs receive the
friendly channel names when loaded; archives without those logs cannot recover
missing raw measurements.

The noise mask powers now follow the user's lab-matched convention:
`ones(3,1)*(gyro.noise_density*(pi/180))^2*gyro.BW` and
`ones(3,1)*(accel.noise_density*g)^2*accel.BW`, without sample-rate division.
Startup gyro noise uses the same resulting variance. New noisy examples set
native `gyro_calib_noise_limit=200` so this larger stationary noise can calibrate.
Older presets keep their saved native threshold; adjust it in the gyro panel if
the firmware reports calibration/arming failure.

App deletion now disposes the progress timer, controller, process and retained
data even when MATLAB bypasses the window's close callback. Plot/load actions
are guarded during run finalization, repeated selections do not duplicate the
same run/signal trace, and display updates use manual limits to avoid automatic
axis-limit feedback. Saving large runs still takes time; the status shows when
the app is archiving data.

Add this folder to the MATLAB path if the launcher has not already done so. The helper functions can be used independently of the GUI:

```matlab
runs = hover.listRuns("C:\path\to\results-library");
run = hover.loadRun(runs(1).Folder);

% Stable keys are convenient for repeatable comparisons.
roll = run.Signals(strcmp({run.Signals.Key}, 'state.phi'));
plot(roll.Time, roll.Data)
xlabel('Time [s]')
ylabel('Roll [rad]')
grid on

settings = hover.loadPreset("C:\path\to\preset.json");
variables = hover.buildVariables(settings);
```

Each signal has `Key`, `Name`, `Group`, `Unit`, `Time`, `Data`, and `Source` fields. `Time` and `Data` are column vectors. State keys use the names in the state ordering, for example `state.phi`, `estimate.phi`, and `error.phi`.

## Verification

From the workbench folder, run:

```matlab
results = runtests('tests');
assert(all([results.Passed]))
```

The tests check the default variables against the initialization portion of the original script without running the script's simulation or plotting sections. They also cover dependent calculations, settings validation, preset round trips, differing logged-array orientations, complete run archive round trips, and storage without model or script copies. The application and model are also exercised through the MATLAB MCP server during development.

`flightAnalysisPlotTest` checks all six panels through both the plotting helper
and the real app callback, ANGLE/rate/yaw/receiver behavior, numerical RMS and
raw-gyro units, missing historical logs, Home and independent detached plots.
The controller retains caught analysis failures in `LastAnalysisError` so an
empty page cannot pass a test merely because its exception was handled.

The app keeps its settings and simulation output separate from the original script. If `lin_hover.m` is intentionally changed later, update the app defaults/calculations and rerun the parity test to keep both workflows consistent.
