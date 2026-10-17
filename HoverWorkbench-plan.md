# Hover Workbench implementation plan

## Plot navigation and responsiveness (2026-10-17)

Reproduced Home/default X limits of [0,1] and 9,024,028 rendered samples for
a 60 s archive. Remove cross-tab linked axes; explicitly fit each run's full
duration and save that as its documented zoom reset baseline. Render only
the selected default subtab. Use viewport-dependent min/max sample selection
to retain extrema in broad views and exact samples when zoomed in, keeping
archives and CSV/workspace exports unchanged. Add independent undocked figure
snapshots retaining original samples, and a multiselect removal dialog for
Explore traces across runs. Verify Home after zoom, different run durations,
spikes/NaN gaps, full detail on zoom, undocked independence and targeted removal
using MATLAB MCP and saved noisy data. Storage remains v7.3 MAT (HDF5).

## Default plot update (2026-10-16)

Separate attitude, angular rates, position and body velocity into four axes
on each of the True state and Estimated state subtabs. Keep controls and
separate attitude/rate errors on a third subtab. Use UIAxes in grid layouts
inside a grid-managed tab group, with linked time axes. Preserve the saved
samples without display smoothing. Native position/velocity channels are
placeholders, so label those plots unavailable instead of plotting zeros;
legacy archives with actual estimates retain their plots. Verify by loading
existing noisy-run archives, checking plotted units/data, and inspecting the
rendered app. References: matlab-build-app editing guide and matlab-build-chart
multiple-axes reference. The simulation and sensor/filter settings stay intact.

## Original implementation plan

Architecture: MATLAB UIFigure with an App Designer `.mlapp` shell (R2025b),
readable controller/helper `.m` files, and a settings/results explorer layout.
The existing `lin_hover.m` and `lin_hover_sim.slx` remain untouched.

- Stable header: title, run label, Run/Stop, status and simulation progress.
- Settings page: category navigation and scrollable labeled editors with units;
  numeric tables for initial/reference state and inertia; derived values read-only.
- Default plots page: the four plots from the initialization script, optionally
  rendered after each run, selectable for any archived run.
- Explore runs page: persistent run library and searchable signal tree at left;
  plot tabs at right. Double-click adds to the current plot or creates a new plot.
  Workspace, CSV, and image export; reload settings from a previous run.
- Every completed or stopped run stores a raw SimulationOutput, normalized time
  series, inputs, derived variables, source snapshots, and metadata in one unique
  folder. JSON presets are separately reusable. No arbitrary expression evaluation
  is used for editable settings.

Simulation execution uses Simulink's native asynchronous Simulation object, not
thread workers (Simulink is not supported by backgroundPool). A cheap periodic
timer only displays status; native simulation completion triggers archival.
Initialization/archival may briefly block with explicit progress feedback.

References used: matlab-build-app references/uifigure/{guide,grid-layout,
containers,components,callbacks,layout-patterns}.md for all structural grids;
references/app-designer/{agent-guide-shared,agent-guide-mlapp}.md for serialization;
references/background-tasks.md for thread support limits and references/timers.md
for polling cleanup; matlab-build-chart for explicit UIAxes and exportgraphics.

Implementation sequence: settings/validation and data normalization/storage in
parallel; App Designer shell and controller; source parity tests; actual simulation
through MATLAB MCP; preset/run reload and plot interaction tests; visual inspection.

Files: `1_Hover Simulation Work/hoverWorkbench.m` launcher,
`1_Hover Simulation Work/HoverWorkbench/HoverWorkbench.mlapp`, controller class,
`+hover` package, tests, README. Runtime `data/` is ignored by Git.
# Stability and raw IMU follow-up (2026-10-17)

Keep the existing App Designer shell and external controller. Reproduce and fix
controller/timer disposal, prevent overlapping run/load/plot callbacks, and keep
graphics limit updates from re-entering auto-limit calculation. Test repeated
app destruction, repeated runs, signal selection/removal and zoom/pan/clear.
Expose measured IMU inputs as named raw gyro/accelerometer channels with SI and
display units. Restore the requested white-noise mask powers without division
by sensor sample rate, including matching startup calibration noise. Verify a
noisy nonlinear case with static gyro PT1 at 5 Hz, dynamic/second gyro LPFs off,
and native accelerometer PT2 at 5 Hz; archive settings, results and metrics.
Consolidate case selection, duration, fidelity, noise, drag, mode and throttle
on Run setup. Remove decay-time damping editors and use reference-speed drag
for app runs; retain coefficients when drag is disabled. Present gyro and
accelerometer parameters in separate titled panels with active native filters.

Flight analysis follow-up: reproduce the saved-run plotting failure; use named
line style properties with the bounded renderer. Label command tracking,
complementary angle/rate feedback, estimator error, native rate PID terms,
actuator outputs and raw sensor error explicitly. Add all-six-panel tests for
angle/rate modes, missing historical logs, Home/zoom and app error reporting;
verify the user's saved hover and inspect the updated page and undocked figure.
