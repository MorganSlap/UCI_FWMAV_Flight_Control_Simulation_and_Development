param([string]$Python = '')
$ErrorActionPreference = 'Stop'
if (!$Python) {
    # Default setup is now portable and leaves any development venv untouched.
    & "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'launch.ps1') -SetupOnly
    if ($LASTEXITCODE -ne 0) { throw 'Desktop runtime setup failed. See build/desktop-setup.log.' }
    return
}
$venv = Join-Path $PSScriptRoot 'build/venv'
if (Test-Path -LiteralPath $venv) { throw 'A development environment already exists in build/venv and was left unchanged. Use its Python directly, or choose a new checkout for another development interpreter.' }
& $Python -m venv $venv
if ($LASTEXITCODE -ne 0) { throw 'Python virtual environment creation failed.' }
$venvPython = Join-Path $venv 'Scripts/python.exe'
& $venvPython -m pip install --require-hashes --only-binary :all: -r (Join-Path $PSScriptRoot 'requirements-lock.txt')
if ($LASTEXITCODE -ne 0) { throw 'Python dependency installation failed.' }
& $venvPython -c 'import tkinter, numpy, scipy, matplotlib, h5py; print("Desktop UI dependencies are ready.")'
if ($LASTEXITCODE -ne 0) { throw 'Desktop UI dependency check failed.' }
