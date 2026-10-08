# Hover Workbench

A settings, simulation, and analysis app for `lin_hover_sim.slx`, built with MATLAB App Designer components. It reads the same initial values as `lin_hover.m` and independently calculates the variables needed by the model. Neither the initialization script nor the model needs to be edited.

The app has three pages: **Settings**, **Default plots**, and **Explore runs**.
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

The state order is `[x y z u v w phi theta psi p q r]`. Positions are in metres, translational velocities in metres per second, angles in radians, and body rates in radians per second. The body/NED vertical direction is positive down. Default plots convert attitude and angular rate to degrees and degrees per second; signal exports retain the units shown by the signal browser.

The script's behavior when noise is disabled is preserved: the effective Mahoney gains become `Kp = 0.25` and `Ki = 0`. These effective values can therefore differ from the stored requested estimator settings.

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

Default plotting can be enabled or disabled independently of saving results. When enabled, the app displays the script's four plots: true states/rates, trim-adjusted controls, estimated attitude/rates, and true-minus-estimated errors. Truth is interpolated onto estimator timestamps for the error plots.

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

The app keeps its settings and simulation output separate from the original script. If `lin_hover.m` is intentionally changed later, update the app defaults/calculations and rerun the parity test to keep both workflows consistent.
