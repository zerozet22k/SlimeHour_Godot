@echo off
setlocal EnableExtensions DisableDelayedExpansion
rem Usage: PLAY_ANDROID.bat [device-serial]
rem Installs the existing APK on a connected phone or running emulator.
set "APK=%~dp0build\SlimeHour-debug.apk"
set "ADB_EXE="
if defined ANDROID_SDK_ROOT if exist "%ANDROID_SDK_ROOT%\platform-tools\adb.exe" set "ADB_EXE=%ANDROID_SDK_ROOT%\platform-tools\adb.exe"
if not defined ADB_EXE if defined ANDROID_HOME if exist "%ANDROID_HOME%\platform-tools\adb.exe" set "ADB_EXE=%ANDROID_HOME%\platform-tools\adb.exe"
if not defined ADB_EXE if exist "%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe" set "ADB_EXE=%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe"
if not defined ADB_EXE if exist "%~dp0platform-tools\adb.exe" set "ADB_EXE=%~dp0platform-tools\adb.exe"
if not defined ADB_EXE for /f "delims=" %%A in ('where adb.exe 2^>nul') do if not defined ADB_EXE set "ADB_EXE=%%A"
if not defined ADB_EXE (
  echo Android Platform Tools were not found.
  echo Install them through Android Studio, or extract platform-tools beside this BAT.
  goto failed
)
if not exist "%APK%" (
  echo APK not found: "%APK%"
  echo Export the Android preset in Godot first.
  goto failed
)
set "TARGET="
if not "%~1"=="" set TARGET=-s "%~1"
echo Checking Android connection...
"%ADB_EXE%" %TARGET% get-state
if errorlevel 1 (
  echo.
  echo Connect your phone, enable USB debugging, and accept its authorization prompt.
  echo Or start an Android emulator before running this script.
  echo If multiple devices are connected, run PLAY_ANDROID.bat device-serial
  "%ADB_EXE%" devices
  goto failed
)
echo Installing Slime Hour...
"%ADB_EXE%" %TARGET% install -r "%APK%"
if errorlevel 1 goto failed
echo Launching Slime Hour...
"%ADB_EXE%" %TARGET% shell am start -W -a android.intent.action.MAIN -c android.intent.category.LAUNCHER -p com.crowdrush.neonfront
if errorlevel 1 goto failed
echo Done. Slime Hour is running on your Android device.
exit /b 0

:failed
echo.
echo Android launch did not complete. See the message above.
pause
exit /b 1
