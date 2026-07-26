@echo off
REM Uninstall improved Windows Service

setlocal EnableDelayedExpansion

REM Check if running as administrator
net session >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo ERROR: This script must be run as Administrator
    echo Right-click on this file and select "Run as administrator"
    pause
    exit /b 1
)

set "SCRIPT_DIR=%~dp0"
set "SERVICE_SCRIPT=%SCRIPT_DIR%service_wrapper.py"

echo Uninstalling Face Recognition Server Windows Service...

REM Stop the service
echo Stopping service...
sc stop "FaceRecognitionServer"
timeout /t 3 /nobreak >nul

REM Remove the service using Python script
echo Removing service...
python "%SERVICE_SCRIPT%" remove

if %ERRORLEVEL%==0 (
    echo ✓ Service uninstalled successfully
) else (
    echo Service removal completed (may not have existed)
)

echo.
echo Uninstallation complete!
pause