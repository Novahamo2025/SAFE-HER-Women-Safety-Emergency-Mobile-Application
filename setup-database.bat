@echo off
setlocal enabledelayedexpansion

echo ==============================================================================
echo SafeHer: Database Setup Script
echo ==============================================================================

set "PSQL_CMD=psql"

where psql >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    if exist "C:\Program Files\PostgreSQL\16\bin\psql.exe" (
        set "PSQL_CMD=C:\Program Files\PostgreSQL\16\bin\psql.exe"
    ) else if exist "C:\Program Files\PostgreSQL\15\bin\psql.exe" (
        set "PSQL_CMD=C:\Program Files\PostgreSQL\15\bin\psql.exe"
    ) else (
        echo Error: PostgreSQL psql.exe not found.
        echo Please ensure PostgreSQL is installed.
        pause
        exit /b 1
    )
)

echo Found PostgreSQL at: "!PSQL_CMD!"
echo Setting up PostgreSQL database 'safeher'...

"!PSQL_CMD!" -U postgres -d postgres -c "CREATE DATABASE safeher;"
if %ERRORLEVEL% EQU 0 (
    echo Database 'safeher' created successfully.
) else (
    echo Database 'safeher' might already exist. Proceeding to schema migration...
)

echo Applying V1 schema...
"!PSQL_CMD!" -U postgres -d safeher -f "%~dp0safeher-database\V1__init_schema.sql"

echo Applying V2 seed data...
"!PSQL_CMD!" -U postgres -d safeher -f "%~dp0safeher-database\V2__seed_data.sql"

echo ==============================================================================
echo Database setup completed successfully!
echo ==============================================================================
pause
