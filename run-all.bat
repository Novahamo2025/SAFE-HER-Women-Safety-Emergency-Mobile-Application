@echo off
echo ==============================================================================
echo SafeHer: Full Stack Launcher
echo ==============================================================================
echo 1. Launching Spring Boot Backend in a separate window...
start "SafeHer Backend (Spring Boot 8080)" cmd /k "%~dp0run-backend.bat"

echo 2. Launching React Admin Portal in a separate window...
start "SafeHer Admin (Vite 5173)" cmd /k "%~dp0run-admin.bat"

echo.
echo ==============================================================================
echo Services started!
echo - Backend API:  http://localhost:8080
echo - Admin Portal: http://localhost:5173
echo.
echo To run the Flutter Mobile app, connect your phone and double-click 'run-mobile.bat'
echo ==============================================================================
pause
