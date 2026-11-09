@echo off
setlocal
call "%~dp0DesktopSIL\Open Desktop SIL.cmd" %*
exit /b %errorlevel%
