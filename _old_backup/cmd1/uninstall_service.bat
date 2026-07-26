@echo off
REM Uninstallation script for Face Recognition Server Windows Service
REM This script removes the service from Windows startup

setlocal EnableDelayedExpansion

REM Check if running as administrator
net session >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo ERROR: This script must be run as Administrator
    echo Right-click on this file and select "Run as administrator"
    pause
    exit /b 1
)

set "SERVICE_NAME=FaceRecognitionServer"

echo Uninstalling Face Recognition Server Windows Service...

REM Check if service exists
sc query "%SERVICE_NAME%" >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo Service "%SERVICE_NAME%" does not exist
    goto :end
)

REM Stop the service if it's running
echo Stopping service...
sc stop "%SERVICE_NAME%"
if %ERRORLEVEL%==0 (
    echo Service stopped successfully
    timeout /t 3 /nobreak >nul
) else (
    echo Service was not running or failed to stop
)

REM Delete the service
echo Deleting service...
sc delete "%SERVICE_NAME%"
if %ERRORLEVEL%==0 (
    echo ✓ Service uninstalled successfully
) else (
    echo ERROR: Failed to delete service
)

:end
echo.
echo Uninstallation complete!
pause