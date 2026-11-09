@echo off
setlocal
rem The policy override applies only to this process, never to machine settings.
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0launch.ps1" %*
if errorlevel 1 (
    echo.
    echo Desktop SIL could not open. The error and setup log path are shown above.
    pause
    exit /b 1
)
endlocal
