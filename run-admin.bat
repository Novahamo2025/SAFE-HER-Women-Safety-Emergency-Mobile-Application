@echo off
echo ==============================================================================
echo SafeHer: Starting React Admin Dashboard (Vite + TypeScript)
echo ==============================================================================
cd /d "%~dp0safeher-admin"

if not exist "node_modules\" (
    echo Installing node dependencies...
    npm install
)

echo Starting Vite development server...
echo The dashboard will open at http://localhost:5173
npm run dev
