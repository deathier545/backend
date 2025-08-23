@echo off
echo Installing WebSocket dependencies...
npm install ws

echo.
echo Starting WebSocket-enabled backend server...
node server.js

pause
