@echo off
echo ==============================================================================
echo SafeHer: Starting Spring Boot Backend (Java 21)
echo ==============================================================================
cd /d "%~dp0safeher-backend"

where mvn >nul 2>nul
if %ERRORLEVEL% EQU 0 (
    echo Using system Maven...
    mvn spring-boot:run
) else (
    if exist "mvnw.cmd" (
        echo Using Maven wrapper...
        mvnw.cmd spring-boot:run
    ) else (
        echo Error: Neither Maven (mvn) nor mvnw wrapper found.
        echo Please ensure Java 21 and Maven are installed and added to your PATH.
        pause
    )
)
