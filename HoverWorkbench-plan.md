# Hover Workbench implementation plan

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
