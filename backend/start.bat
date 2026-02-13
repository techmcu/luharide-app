@echo off
echo Stopping all node processes...
taskkill /F /IM node.exe >nul 2>&1

timeout /t 2 /nobreak >nul

echo Starting backend server...
npm start
