@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
set "GODOT_EXE="
where godot >nul 2>nul && set "GODOT_EXE=godot"
where godot4 >nul 2>nul && if not defined GODOT_EXE set "GODOT_EXE=godot4"
if not defined GODOT_EXE (
  for %%F in ("%~dp0Godot_v*win64*.exe" "%~dp0Godot_v*.exe" "%~dp0godot.exe") do (
    if exist "%%~fF" if not defined GODOT_EXE set "GODOT_EXE=%%~fF"
  )
)
if not defined GODOT_EXE (
  echo ==========================================================
  echo   SLIME HOUR -- GODOT 4 PROJECT
  echo ==========================================================
  echo Godot was not detected.
  echo Download the STANDARD Godot for Windows, not the .NET edition:
  echo https://godotengine.org/download/windows/
  echo.
  echo Open Godot, Import this folder's project.godot, then press F5.
  echo Or put the downloaded Godot_v4...exe beside this BAT.
  pause
  exit /b 1
)
echo Launching Slime Hour with: !GODOT_EXE!
if not exist "%~dp0.godot" (
  echo First launch: opening the Godot editor to import project assets.
  echo When the editor opens, press F5 to play.
  "!GODOT_EXE!" --editor --path "%~dp0"
) else (
  "!GODOT_EXE!" --path "%~dp0"
)
if errorlevel 1 (
  echo Godot reported a launch error. Read the engine Output panel.
  pause
)
