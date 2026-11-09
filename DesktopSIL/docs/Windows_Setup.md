# Running Desktop SIL on another Windows computer

## First launch

1. Download or clone the **feature/SITL_sim_Codex** branch. A download of a
   different branch may contain the older launcher.
2. For a ZIP download, use **Extract All** first. Keep the complete folder
   structure. Put it in a writable local folder such as Documents, not Program
   Files. Do not run the launcher from inside the ZIP viewer.
3. Double-click **Open Desktop SIL.cmd** in the repository root. The same
   launcher is also available inside `DesktopSIL`.
4. Leave the setup window open on the first launch. It downloads a private
   Python 3.12.14 installation with Tk and the locked plotting/data libraries.
   The interface opens after verification completes. Subsequent launches reuse
   these files and work offline.

Supported target: Intel/AMD 64-bit Windows 10/11. Windows ARM, macOS and Linux
are not supported by the included native executable. Internet access to GitHub
and PyPI is needed for first setup. No separately installed Python, MATLAB,
MATLAB Runtime, Cygwin, compiler, Git, or administrator access is needed to
run a downloaded ZIP. Corporate policy may still require IT approval to run
downloaded scripts or executables.

Flights run locally and need no inbound network permission. The desktop build
does not open the unused Betaflight virtual-UART TCP listeners. This change is
limited to desktop runs; the separate MATLAB/Simulink host retains its bridge.

The setup changes only files under `DesktopSIL/build`. It does not register
Python, change the system/user PATH, change permanent PowerShell policy, or
install into another Python environment. The `.cmd` file sets PowerShell policy
for its child process only. The package manager download and Python package
downloads have pinned checksums. The Python runtime is version-pinned and
retrieved through uv's managed distribution metadata.

## What is included and what is installed

| Location | Purpose |
| --- | --- |
| `runtime/windows-x64/` | Git-tracked native flight engine, two required DLLs, file/source manifest |
| `build/portable-python/` | Downloaded CPython and Tk, private to this checkout |
| `build/runtime-venv/` | Downloaded and verified application libraries |
| `build/bootstrap/`, `build/uv-cache/` | Download helper and cache |
| `build/venv/` | Optional existing development Python environment, reused if healthy and never changed by the launcher |
| `build/hover_desktop_sil.exe` | Local development engine, preferred over the packaged engine when present |
| `runs/` | Default run and Monte Carlo archives, kept separate from runtime setup |

The GUI runs the `.py` files in the checkout, so Python UI changes are visible
on the next launch. The native engine is already compiled from the generated
plant C and pinned Betaflight firmware. Downloading Python does not regenerate
or change the plant. Run metadata records both the selected engine path and its
SHA-256, so results identify the engine that produced them.

## Troubleshooting

- **Setup failed or a download was interrupted:** read the displayed error and
  retry the launcher. Setup preserves an incomplete private environment before
  replacing it. Do not delete the development environment or run archives.
- **Proxy/network error:** allow GitHub release downloads and `pypi.org` /
  `files.pythonhosted.org`. The package manager uses Windows trusted certificates.
- **App exits after setup:** read `build/desktop-launch.log`. Setup and dependency
  diagnostics are in `build/desktop-setup.log` and `build/python-check.log`.
- **A runtime file is missing or its checksum is wrong:** extract the full repo
  again. Check whether endpoint protection quarantined it. Do not disable
  endpoint protection; ask IT to review the file if needed.
- **Moved/copied a previously initialized checkout:** launch it again. A broken
  application venv is recreated locally. A copied development venv is left
  alone. Prefer copying the repository files without the ignored `build` folder.
- **Using an existing development build:** restart the app after rebuilding.
  A broken local native build is reported rather than silently falling back to
  the older packaged plant. Finish the build or rename the local executable if
  you intentionally want to use the packaged snapshot.

Setup without opening the interface:

```powershell
& '.\Open Desktop SIL.cmd' -SetupOnly
```

To test the private application Python even when a development venv exists:

```powershell
& '.\Open Desktop SIL.cmd' -SetupOnly -ForceManaged
& .\DesktopSIL\build\runtime-venv\Scripts\python.exe DesktopSIL/tests/verify_portable.py --smoke
```

## Continuing plant development

The original model, initialization script, MATLAB app, generated C workflow,
toolchain and development environment stay in their existing locations.

1. Edit the original Simulink plant.
2. In MATLAB, regenerate both plant variants using `buildPlantCode("high")` and
   `buildPlantCode("low")` from `DesktopSIL/matlab`.
3. Run `DesktopSIL/build.ps1`. Pass `-MatlabRoot` for another MATLAB installation.
   On a new development computer, first install the required MATLAB codegen
   products and run `Betaflight/build-host.ps1 -InstallToolchain`.
4. Run the numerical/GUI checks described in the main README. Restart the app.
   It automatically uses the new **local build**. Nothing needs to be installed
   into Python when only the plant equations change.
5. When the changed plant is ready for other users, run
   `DesktopSIL/publish-runtime.ps1`. It copies the three native files and their
   build manifest into the Git-tracked runtime folder. It refuses to package
   code or binaries changed since the recorded build.
6. Commit the generated C, relevant model/source changes, and updated runtime
   together, then push the branch. Other computers receive that plant with their
   next download/pull. A developer with an existing local build must rebuild to
   use updated source, because local builds deliberately take precedence.

Packaging does not replace MATLAB code generation. It supplies a verified
compiled snapshot for users who only need to configure, run, and analyze cases.

The Windows CI workflow runs first-use setup and real packaged-engine tests
from a fresh checkout. It requires no MATLAB or development toolchain.
