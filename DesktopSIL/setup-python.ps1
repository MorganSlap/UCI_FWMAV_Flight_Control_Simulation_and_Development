param([string]$Python = '')
$ErrorActionPreference = 'Stop'
if (!$Python) {
    $bundled = Join-Path $env:USERPROFILE '.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'
    if (Test-Path -LiteralPath $bundled) { $Python = $bundled }
    else { $Python = (Get-Command python.exe -ErrorAction Stop).Source }
}
$venv = Join-Path $PSScriptRoot 'build/venv'
& $Python -m venv $venv
if ($LASTEXITCODE -ne 0) { throw 'Python virtual environment creation failed.' }
$venvPython = Join-Path $venv 'Scripts/python.exe'
& $venvPython -m pip install -r (Join-Path $PSScriptRoot 'requirements.txt')
if ($LASTEXITCODE -ne 0) { throw 'Python dependency installation failed.' }
& $venvPython -c 'import tkinter, numpy, scipy, matplotlib, h5py; print("Desktop UI dependencies are ready.")'
if ($LASTEXITCODE -ne 0) { throw 'Desktop UI dependency check failed.' }
