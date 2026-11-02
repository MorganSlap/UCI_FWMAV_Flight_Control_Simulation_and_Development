# MATLAB workbench parity checklist

The reference is the current `HoverWorkbenchController.m`, its `+hover` helpers,
and `bf.Configurator`. Legacy script fields that no longer drive Betaflight
must not be presented as active native firmware controls.

## Simulation and configuration
- [x] Generated nonlinear plant, actuators and sensors; actual Betaflight.
- [x] Generated linearized plant selectable without rebuilding.
- [x] Four complete examples, script-default reset, editable held command sequence.
- [x] Duration, fidelity, noise/seed, drag, mode/throttle on Run setup.
- [x] All active vehicle, reference-drag, sensor and estimator parameters.
- [x] Full initial state and reference, angular input in degrees.
- [x] PID/rate/battery profiles, simplified tuning, 1–16 PID divider.
- [x] Receiver map/ranges, AUX/mixer commands, custom 16-channel calibration/flight.
- [x] Warmup, arm/spool times, receiver rate, calibration switch.
- [x] Searchable firmware catalog with actual constraints; CLI/JSON import/export.
- [x] Derived values, settings search, run label/notes, configurable results library.
- [x] Isolated native processes; run/pause/resume/stop, repeated-run tests.

## Data, plots and analysis
- [x] Default plots toggle; truth, estimates, errors and controls; unavailable estimates explicit.
- [x] Full-duration reset, interactive zoom/pan and peak-preserving display.
- [x] Run selectors, signal search/groups, overlay/replace/new-plot double click.
- [x] Clear all/selected traces, close/new plots, undock snapshots, PNG/PDF export.
- [x] Flight analysis: seven explained panels, axis selector, saved-settings RMS metrics.
- [x] Ideal and raw IMU, commands, native diagnostics, altitude/rate/errors in browser.
- [x] Full-resolution selected-signal CSV/MAT exports and MATLAB workspace helper.
- [x] Historical MATLAB preset/run import; reuse saved settings, inspect metadata.
- [x] Settings/data-only archives, efficient HDF5 with signal units and provenance.

## Completion evidence
- [x] Nonlinear C/Simulink equivalence with and without noise.
- [x] Original Betaflight-host exact input replay (29,202 exchanges).
- [x] Linear equivalence and expanded native configuration checks.
- [x] Expanded GUI callback, plotting, export and archive tests.
- [x] Final visual inspection and architecture/build guide/presentation (21 slides).

## ODE5 and signal semantics
- [x] Both generated plants use ODE5; 16/32/64 kHz integration is configurable.
- [x] Five-minute noisy and quiet step-halving comparisons passed.
- [x] Exact Mahony input taps are distinct from processed rate feedback.
- [x] All attitude/rate estimation errors use True minus Estimated.
