@echo off
REM Remove invisible Face Recognition Server startup

setlocal EnableDelayedExpansion

REM Check if running as administrator
net session >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo ERROR: This script must be run as Administrator
    echo Right-click on this file and select "Run as administrator"
    pause
    exit /b 1
)

set "REG_KEY=HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
set "REG_NAME=FaceRecognitionServer"

echo Removing invisible Face Recognition Server startup...

REM Remove registry entry
reg delete "%REG_KEY%" /v "%REG_NAME%" /f

if %ERRORLEVEL%==0 (
    echo ✓ Invisible startup removed successfully
) else (
    echo Registry entry not found or failed to remove
)

REM Also stop any running Python processes for this app
taskkill /f /im pythonw.exe 2>nul

echo.
echo Removal complete!
pause