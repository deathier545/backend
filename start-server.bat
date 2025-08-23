@echo off
echo ========================================
echo    Moon HUB Admin Backend Server
echo ========================================
echo.
echo Starting server...
echo.

REM Check if Node.js is installed
node --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Node.js is not installed or not in PATH
    echo Please install Node.js from https://nodejs.org/
    pause
    exit /b 1
)

REM Check if dependencies are installed
if not exist "node_modules" (
    echo Installing dependencies...
    npm install
    if %errorlevel% neq 0 (
        echo ERROR: Failed to install dependencies
        pause
        exit /b 1
    )
)

REM Start the server
echo Server is starting on port 3000...
echo Press Ctrl+C to stop the server
echo.
echo Health check: http://localhost:3000/api/health
echo Statistics: http://localhost:3000/api/stats
echo.
npm start

pause
