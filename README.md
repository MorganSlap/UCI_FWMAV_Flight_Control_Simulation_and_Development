# UCI_FWMAV_Flight_Control_Simulation_and_Development
This repository contains MATLAB/Simulink code, models, as well as other general analysis and notes for simulating flight and developing flight control systems for the flapping wing micro air vehicles (FWMAV) of the FWMAV project at the University of California Irvine.

## Open the desktop simulation on Windows

Download or clone **feature/SITL_sim_Codex**, extract the complete ZIP if needed,
then double-click **Open Desktop SIL.cmd** in this folder. On Intel/AMD 64-bit
Windows 10/11, the first launch installs private Python and plotting libraries.
Keep the setup window open until the interface appears. Internet is needed for
first setup; no MATLAB or separately installed Python is needed to run the app.

See the [Desktop SIL guide](DesktopSIL/README.md) and
[Windows setup/troubleshooting](DesktopSIL/docs/Windows_Setup.md).
The original MATLAB/Simulink workflow remains available. Local native builds
take precedence over the packaged engine, so plant changes can still be
regenerated, compiled, tested, and distributed.
