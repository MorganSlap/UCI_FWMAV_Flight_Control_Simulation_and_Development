$ErrorActionPreference = 'Stop'
$candidates = @(
    (Join-Path $PSScriptRoot 'build/venv/Scripts/pythonw.exe'),
    (Join-Path $env:USERPROFILE '.cache/codex-runtimes/codex-primary-runtime/dependencies/python/pythonw.exe'),
    (Join-Path $env:USERPROFILE '.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe')
)
$python = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (!$python) { $python = (Get-Command pythonw.exe -ErrorAction SilentlyContinue).Source }
if (!$python) { throw 'Install Python with tkinter and NumPy, then run python DesktopSIL/app.py.' }
# This is the interactive application window, not a background helper.
Start-Process -FilePath $python -ArgumentList @(('"'+(Join-Path $PSScriptRoot 'app.py')+'"')) -WorkingDirectory $PSScriptRoot -WindowStyle Normal
