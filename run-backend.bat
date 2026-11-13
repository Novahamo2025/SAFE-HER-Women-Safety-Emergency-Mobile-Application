@echo off
setlocal

echo ==============================================================================
echo Svasheild: Starting Spring Boot Backend (Java 21)
echo ==============================================================================
echo Target Database: Supabase PostgreSQL (aws-0-ap-northeast-2.pooler.supabase.com)
echo User: postgres.pxsizfegyxoqsfgdefvm
echo ==============================================================================

:: Load from .env if present
call :loadDatabaseConfig

if not defined SUPABASE_DB_URL set "SUPABASE_DB_URL=jdbc:postgresql://aws-0-ap-northeast-2.pooler.supabase.com:5432/postgres?sslmode=require"
if not defined SUPABASE_DB_USERNAME set "SUPABASE_DB_USERNAME=postgres.pxsizfegyxoqsfgdefvm"

:: Prompt if still not set
if not defined SUPABASE_DB_PASSWORD echo.
if not defined SUPABASE_DB_PASSWORD echo [NOTICE] SUPABASE_DB_PASSWORD is not set.
if not defined SUPABASE_DB_PASSWORD echo You can save it permanently in a .env file (SUPABASE_DB_PASSWORD=your_password).
if not defined SUPABASE_DB_PASSWORD echo.
if not defined SUPABASE_DB_PASSWORD set /p "SUPABASE_DB_PASSWORD=Please enter your Supabase database password: "

cd /d "%~dp0safeher-backend"

where mvn >nul 2>nul
if not errorlevel 1 goto use_system_maven
if not exist "mvnw.cmd" goto missing_maven
echo Using Maven wrapper...
mvnw.cmd spring-boot:run
goto :eof

:use_system_maven
echo Using system Maven...
mvn spring-boot:run
goto :eof

:missing_maven
echo Error: Neither Maven (mvn) nor mvnw wrapper found.
echo Please ensure Java 21 and Maven are installed and added to your PATH.
pause
goto :eof

:loadDatabaseConfig
if not exist "%~dp0.env" goto :eof
for /f "usebackq tokens=1,* delims==" %%A in ("%~dp0.env") do (
    if "%%A"=="SUPABASE_DB_PASSWORD" if not defined SUPABASE_DB_PASSWORD set "SUPABASE_DB_PASSWORD=%%B"
    if "%%A"=="SUPABASE_DB_URL" if not defined SUPABASE_DB_URL set "SUPABASE_DB_URL=%%B"
    if "%%A"=="SUPABASE_DB_USERNAME" if not defined SUPABASE_DB_USERNAME set "SUPABASE_DB_USERNAME=%%B"
)
goto :eof
