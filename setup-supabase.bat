@echo off
setlocal enabledelayedexpansion

echo ==============================================================================
echo Svasheild: Supabase Database Migration & Verification
echo ==============================================================================
echo Host:     aws-0-ap-northeast-2.pooler.supabase.com
echo Port:     5432
echo Database: postgres
echo User:     postgres.pxsizfegyxoqsfgdefvm
echo ==============================================================================

if not defined SUPABASE_DB_PASSWORD (
    if exist "%~dp0.env" (
        for /f "usebackq tokens=1,* delims==" %%A in ("%~dp0.env") do (
            if "%%A"=="SUPABASE_DB_PASSWORD" set "SUPABASE_DB_PASSWORD=%%B"
        )
    )
)

if not defined SUPABASE_DB_PASSWORD (
    echo.
    set /p "SUPABASE_DB_PASSWORD=Enter your Supabase database password: "
)

set "PGPASSWORD=!SUPABASE_DB_PASSWORD!"

set "PSQL_CMD=psql"
where psql >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    if exist "C:\Program Files\PostgreSQL\16\bin\psql.exe" (
        set "PSQL_CMD=C:\Program Files\PostgreSQL\16\bin\psql.exe"
    ) else if exist "C:\Program Files\PostgreSQL\15\bin\psql.exe" (
        set "PSQL_CMD=C:\Program Files\PostgreSQL\15\bin\psql.exe"
    )
)

echo.
echo Testing connection and applying migrations to Supabase...
"!PSQL_CMD!" -h aws-0-ap-northeast-2.pooler.supabase.com -p 5432 -d postgres -U postgres.pxsizfegyxoqsfgdefvm -f "%~dp0safeher-backend\src\main\resources\db\migration\V1__init_schema.sql"

if %ERRORLEVEL% EQU 0 (
    echo.
    echo [OK] V1 schema applied successfully!
    echo Applying V2 seed data...
    "!PSQL_CMD!" -h aws-0-ap-northeast-2.pooler.supabase.com -p 5432 -d postgres -U postgres.pxsizfegyxoqsfgdefvm -f "%~dp0safeher-backend\src\main\resources\db\migration\V2__seed_data.sql"
    echo [OK] Supabase database setup complete!
) else (
    echo.
    echo [ERROR] Connection or migration failed. Please verify your password.
)

pause
