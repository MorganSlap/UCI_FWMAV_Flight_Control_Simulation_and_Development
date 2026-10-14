# Betaflight Configurator implementation plan

Architecture: standalone native MATLAB UIFigure, using grid layouts and a
tabbed parameter editor. This follows the existing project GUI architecture.
The requested Betaflight styling uses a dark native theme and centralized
yellow action accents; standard controls retain automatic theme colors.

The stable header contains firmware identity and load/save/apply actions.
Tabs contain searchable firmware settings, receiver commands, mode commands,
motor mixer commands, and the complete editable CLI configuration. Profile
selectors distinguish profile-scoped and rate-profile-scoped settings.

The parameter catalog comes only from captured `get` output of the compiled
firmware. The complete CLI document preserves commands that are not ordinary
`set` values. The app edits data only: it does not run firmware, write to a
flight controller, or evaluate MATLAB expressions. Apply exports `bfConfig`
to the MATLAB workspace for the simulation initialization script.

Helpers parse firmware constraints, read effective scoped settings, patch
CLI documents, validate typed edits, and save/load versioned JSON or CLI.
Configuration fields are Format, SchemaVersion, CLI, SchemaText, and Firmware.

References read: matlab-build-app `references/uifigure/guide.md`,
`grid-layout.md`, `callbacks.md`, `references/archetypes/tabbed.md`; and
matlab-apply-theme `references/theme-api.md`. The upstream cli.c supplies
the actual range, lookup, array, string, and profile response formats.

Implementation: pure helpers first, class-based GUI next, standalone launcher
last. Parent agent performs MATLAB MCP parser tests and GUI smoke checks with
captured output from the actual firmware build.
