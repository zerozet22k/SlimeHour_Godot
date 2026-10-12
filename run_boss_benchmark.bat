@echo off
rem BOSS BENCHMARK
rem   run_boss_benchmark.bat                     all bosses, Normal + Hard, 4 bots each (parallel, live scoreboard)
rem   run_boss_benchmark.bat 6 normal            6 bots per boss, Normal only
rem   run_boss_benchmark.bat watch               WATCH the bots play every boss in a window
rem   run_boss_benchmark.bat watch necro hard    watch one boss (ids: heli chonkzilla necro kingblob coilqueen
rem                                              glassoracle voidweaver dreadengine stormtitan hiveempress)
if /I "%1"=="watch" goto watch
set TRIALS=%1
if "%TRIALS%"=="" set TRIALS=4
set MODE=%2
if "%MODE%"=="" set MODE=both
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\run_boss_benchmark.ps1" -Trials %TRIALS% -Mode %MODE%
pause
goto :eof

:watch
set BENCH_WATCH=1
set BENCH_TRIALS=2
set BENCH_BOSSES=%2
set BENCH_HARD=0
if /I "%3"=="hard" set BENCH_HARD=1
if "%GODOT%"=="" set GODOT=%~dp0Godot_v4.7.2-stable_win64_console.exe
"%GODOT%" --path "%~dp0." --script res://tools/boss_benchmark.gd
