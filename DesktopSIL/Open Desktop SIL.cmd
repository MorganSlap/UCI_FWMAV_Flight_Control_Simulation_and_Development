@echo off
setlocal
set "SIL_PYTHON=%~dp0build\venv\Scripts\pythonw.exe"
if exist "%SIL_PYTHON%" goto launch
set "SIL_PYTHON=%USERPROFILE%\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\pythonw.exe"
if exist "%SIL_PYTHON%" goto launch
set "SIL_PYTHON="
for /f "delims=" %%P in ('where pythonw.exe 2^>nul') do if not defined SIL_PYTHON set "SIL_PYTHON=%%P"
if defined SIL_PYTHON goto launch
echo Desktop SIL could not find Python with the desktop dependencies.
echo See the setup instructions in "%~dp0README.md".
pause
exit /b 1
:launch
start "" "%SIL_PYTHON%" "%~dp0launch.py"
if errorlevel 1 (
    echo Desktop SIL could not start Python: "%SIL_PYTHON%"
    pause
    exit /b 1
)
endlocal
