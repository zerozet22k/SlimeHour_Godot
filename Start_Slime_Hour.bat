@echo off
setlocal
cd /d "%~dp0"
rem Compatibility shortcut only. All version checking and downloading is
rem handled by SlimeHour.exe itself, with an in-game update screen.
if exist "%~dp0SlimeHour.exe" (
  start "" "%~dp0SlimeHour.exe"
  exit /b 0
)
echo SlimeHour.exe is missing. Extract the full Windows release first.
pause
