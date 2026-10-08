# Validation

Validated through the MATLAB MCP server in MATLAB R2025b on 2026-10-08,
on the existing `codex_test` branch.

- The initial 20 automated tests passed: defaults match every active initialization variable;
  dependent formulas, physical/dimension validation, preset round trips, signal
  orientation (including the 12-sample matrix ambiguity), logged datasets, trim
  and interpolation, archive round trips, and non-overwriting storage.
- The App Designer file was saved through the product, opened, and launched.
- All settings groups and derived-value tables render. Numeric edits propagate
  into the settings used for simulation.
- A full 10-second nonlinear run saved 76 scalar channels. Its state_output,
  controls, and state_estimate structures exactly matched the earlier normal-mode
  baseline using the original script's settings.
- A linear run with changed roll P saved and reloaded its own settings.
- A requested 100-second run was stopped at about 21.4 seconds; partial output
  was archived with status `stopped`.
- Signal double-click callback, multi-tab custom plots, overlays across archived
  runs, workspace timeseries export, restoring a run's settings, and default-plot
  enable/disable were exercised. Plot pages were visually inspected.
- Original script and model hashes were unchanged; no model configuration or
  logging edits were saved.

Original SHA-256 values:

```text
lin_hover.m
c2af4d561d349e1da8cf7d13f65319226f76c76f019e388f0ecbdd226d713d22
lin_hover_sim.slx
c1323d3e069083086ab7dee86f6e9ed8f4e46c33ccffa59aa152e19512339834
```

Development archives/screenshots are kept under ignored `test-output/`.
Normal user runs default to the separate ignored `data/` library.

The follow-up storage change removes model/script copies from new archives;
existing archives and their files remain untouched. A new regression checks
that each archive contains only `settings.json`, `metadata.json`, and `run.mat`,
retains settings, derived variables, raw output, normalized signals, and source
path/hash metadata, and omits legacy embedded source-copy fields. The updated
21-test suite is awaiting a MATLAB MCP rerun.
