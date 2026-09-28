@echo off
setlocal EnableExtensions EnableDelayedExpansion

echo ==============================================================================
echo Svasheild: Launching Flutter Mobile App
echo ==============================================================================

:: ============================================================
:: Flutter
:: ============================================================
set "FLUTTER_CMD=C:\flutter\bin\flutter.bat"

if not exist "%FLUTTER_CMD%" (
echo.
echo ERROR: Flutter was not found:
echo %FLUTTER_CMD%
pause
exit /b 1
)

:: ============================================================
:: Android SDK / ADB
:: ============================================================
set "ADB_EXE=C:\Users\Anu\AppData\Local\Android\sdk\platform-tools\adb.exe"

if not exist "%ADB_EXE%" (
echo.
echo ERROR: ADB was not found:
echo %ADB_EXE%
pause
exit /b 1
)

:: ============================================================
:: SafeHer Flutter project
:: ============================================================
set "PROJECT_DIR=%~dp0safeher-mobile"

if not exist "%PROJECT_DIR%\pubspec.yaml" (
echo.
echo ERROR: Flutter project was not found:
echo %PROJECT_DIR%
echo.
echo Expected file:
echo %PROJECT_DIR%\pubspec.yaml
pause
exit /b 1
)

echo Using Flutter at: "%FLUTTER_CMD%"
echo Using ADB at: "%ADB_EXE%"
echo Project: "%PROJECT_DIR%"
echo.

:: ============================================================
:: Start ADB
:: ============================================================
"%ADB_EXE%" start-server >nul 2>nul

echo Checking connected Android devices...
echo.

set "DEVICE_ID="

for /f "skip=1 tokens=1,2" %%A in ('"%ADB_EXE%" devices') do (
if "%%B"=="device" if not defined DEVICE_ID (
set "DEVICE_ID=%%A"
)
)

if not defined DEVICE_ID (
echo.
echo ERROR: No authorized Android phone was found.
echo.
echo Connected devices:
"%ADB_EXE%" devices
echo.
echo Make sure your Vivo phone is unlocked and USB debugging
echo is enabled.
pause
exit /b 1
)

echo Vivo phone detected:
echo !DEVICE_ID!
echo.

:: ============================================================
:: USB reverse port forwarding
:: PC backend: localhost:8080
:: Phone: localhost:8080
:: ============================================================
echo Configuring USB reverse port forwarding...

"%ADB_EXE%" -s "!DEVICE_ID!" reverse tcp:8080 tcp:8080

if !ERRORLEVEL! EQU 0 (
echo [OK] Phone localhost:8080 -> PC localhost:8080
) else (
echo [WARNING] USB reverse forwarding failed.
echo The Flutter app will still be launched.
)

echo.

:: ============================================================
:: Flutter packages
:: ============================================================
echo ==============================================================================
echo Step 1: Getting Flutter packages...
echo ==============================================================================
echo.

cd /d "%PROJECT_DIR%"

call "%FLUTTER_CMD%" pub get

if !ERRORLEVEL! NEQ 0 (
echo.
echo ERROR: flutter pub get failed.
pause
exit /b 1
)

echo.
echo ==============================================================================
echo Step 2: Launching Svasheild on your phone...
echo ==============================================================================
echo.

call "%FLUTTER_CMD%" run -d "!DEVICE_ID!"

if !ERRORLEVEL! EQU 0 goto :DONE

echo.
echo ERROR: Svasheild could not be launched.
echo.
echo Checking Android devices again:
"%ADB_EXE%" devices

pause
exit /b 1

:DONE

echo.
echo ==============================================================================
echo Svasheild launched successfully.
echo ==============================================================================
echo.

pause