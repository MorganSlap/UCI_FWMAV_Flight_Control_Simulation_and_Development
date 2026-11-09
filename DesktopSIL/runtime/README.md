# Packaged Windows native engine

`windows-x64/` is deliberately included in Git. It contains the compiled
Simulink plant plus the pinned Betaflight SITL firmware and its two runtime
DLLs. It needs no MATLAB Runtime, compiler, or Cygwin installation to run.
`manifest.json` records file checksums, firmware revision, and build-input hashes.

The app prefers `DesktopSIL/build/hover_desktop_sil.exe` when it exists. The
packaged executable is the fallback for a new clone. Both run the same Python
application source, catalogs, presets, plots, and Monte Carlo framework.

To refresh this snapshot after plant changes, regenerate C, run `build.ps1`,
verify the simulation, and run `publish-runtime.ps1`. Publishing refuses source
or binary changes made after the recorded build. Commit the updated runtime
together with its source changes. See [Windows setup](../docs/Windows_Setup.md).

## Component sources and notices

- Generated plant sources: `DesktopSIL/generated/`. Their original MathWorks
  Academic License headers remain in place and apply to the generated code.
- Betaflight: revision `c78d9e7bd24ef60f4324dffde11df26c53d4f29f` at
  <https://github.com/betaflight/betaflight>. The exact host modifications are in
  `Betaflight/host/`; desktop instrumentation and linking are in
  `DesktopSIL/build.ps1` and `DesktopSIL/native/`. `Betaflight/build-host.ps1`
  retrieves the pinned sources and required submodules. GPL-3.0 text is included
  under `licenses/` and already in `Betaflight/host/LICENSE`.
- Cygwin runtime 3.6.11: <https://cygwin.com/>, upstream source repository
  <https://cygwin.com/git.html>. Source packages are available through Cygwin
  setup's source-package option and the Cygwin release archives.
  See `licenses/CYGWIN-COPYING`, `licenses/LGPL-3.0.txt` and `licenses/GPL-3.0.txt`.
- GCC support library: libgcc 14.4.0, source package
  <https://mirrors.kernel.org/sourceware/cygwin/x86_64/release/gcc/gcc-14.4.0-1-src.tar.zst>.
  See `licenses/GCC-RUNTIME-EXCEPTION.txt` and `licenses/GPL-3.0.txt`.

The launcher downloads Astral uv 0.13.7, verifies its pinned SHA-256, and uses
its managed CPython 3.12.14 distribution with Tcl/Tk. Python and package licenses
remain in the downloaded installation. All Python libraries are pinned with
hashes in `requirements-lock.txt`; they are downloaded from PyPI on first use.
