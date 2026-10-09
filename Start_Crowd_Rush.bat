@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0update_and_run.ps1"
if errorlevel 1 (
  echo.
  echo Crowd Rush could not start. See the message above.
  pause
)
