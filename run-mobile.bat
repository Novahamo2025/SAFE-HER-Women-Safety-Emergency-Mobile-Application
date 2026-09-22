@echo off
setlocal enabledelayedexpansion

echo ==============================================================================
echo SafeHer: Launching Flutter Mobile App
echo ==============================================================================

:: Ensure Windows PowerShell and System32 are in PATH for Flutter
set "PATH=%SystemRoot%\System32\WindowsPowerShell\v1.0;%SystemRoot%\System32;%SystemRoot%;C:\flutter\bin;%PATH%"

set "FLUTTER_CMD=flutter"

where flutter >nul 2>nul
if %ERRORLEVEL% EQU 0 goto :RUN_APP

if exist "C:\flutter\bin\flutter.bat" (
    set "FLUTTER_CMD=C:\flutter\bin\flutter.bat"
    goto :RUN_APP
)

if exist "C:\src\flutter\bin\flutter.bat" (
    set "FLUTTER_CMD=C:\src\flutter\bin\flutter.bat"
    goto :RUN_APP
)

echo Error: Flutter SDK could not be located at C:\flutter\bin\flutter.bat.
pause
exit /b 1

:RUN_APP
echo Using Flutter at: "!FLUTTER_CMD!"
echo.

cd /d "%~dp0safeher-mobile"

echo Step 1: Getting Flutter packages...
call "!FLUTTER_CMD!" pub get

echo.
echo Step 2: Launching SafeHer on your Vivo phone...
call "!FLUTTER_CMD!" run

pause
