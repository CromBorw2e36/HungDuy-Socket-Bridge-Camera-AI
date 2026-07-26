@echo off
REM Install Face Recognition Server to Windows Registry Startup
REM This method adds the server to registry for automatic startup

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
set "START_SCRIPT=%SCRIPT_DIR%start_server_hidden.bat"
set "REG_KEY=HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
set "REG_NAME=FaceRecognitionServer"

echo Installing Face Recognition Server to Registry Startup...
echo Script: %START_SCRIPT%

REM Check if start script exists
if not exist "%START_SCRIPT%" (
    echo ERROR: Start script not found: %START_SCRIPT%
    pause
    exit /b 1
)

REM Add registry entry
reg add "%REG_KEY%" /v "%REG_NAME%" /t REG_SZ /d "\"%START_SCRIPT%\"" /f

if %ERRORLEVEL%==0 (
    echo ✓ Face Recognition Server added to Registry Startup
    echo.
    echo The server will start automatically when Windows boots (for all users).
    echo.
    echo To remove, run: uninstall_registry.bat
    echo Or manually delete registry key: %REG_KEY%\%REG_NAME%
) else (
    echo ERROR: Failed to add registry entry
    echo Make sure you are running as Administrator
)

echo.
echo Installation complete!
pause