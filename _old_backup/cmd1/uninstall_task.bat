@echo off
REM Uninstall scheduled task for Face Recognition Server

setlocal EnableDelayedExpansion

REM Check if running as administrator
net session >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo ERROR: This script must be run as Administrator
    echo Right-click on this file and select "Run as administrator"
    pause
    exit /b 1
)

set "TASK_NAME=FaceRecognitionServer"

echo Uninstalling Face Recognition Server scheduled task...

REM Delete the scheduled task
schtasks /delete /tn "%TASK_NAME%" /f
if %ERRORLEVEL%==0 (
    echo ✓ Scheduled task uninstalled successfully
) else (
    echo Task "%TASK_NAME%" does not exist or failed to delete
)

echo.
echo Uninstallation complete!
pause