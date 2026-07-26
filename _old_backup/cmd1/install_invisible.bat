@echo off
REM Install Face Recognition Server using VBScript (completely invisible)
REM This method ensures NO windows are ever shown

setlocal EnableDelayedExpansion

REM Check if running as administrator for registry method
net session >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo ERROR: This script must be run as Administrator
    echo Right-click on this file and select "Run as administrator"
    pause
    exit /b 1
)

set "SCRIPT_DIR=%~dp0"
set "VBS_SCRIPT=%SCRIPT_DIR%start_server_invisible.vbs"
set "REG_KEY=HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
set "REG_NAME=FaceRecognitionServer"

echo Installing Face Recognition Server (Completely Invisible Mode)...
echo VBScript: %VBS_SCRIPT%

REM Check if VBScript file exists
if not exist "%VBS_SCRIPT%" (
    echo ERROR: VBScript file not found: %VBS_SCRIPT%
    pause
    exit /b 1
)

REM Add registry entry to run VBScript invisibly
reg add "%REG_KEY%" /v "%REG_NAME%" /t REG_SZ /d "wscript.exe \"%VBS_SCRIPT%\"" /f

if %ERRORLEVEL%==0 (
    echo ✓ Face Recognition Server installed for invisible startup
    echo.
    echo The server will start completely hidden when Windows boots.
    echo - NO console windows
    echo - NO visible processes  
    echo - Runs silently in background
    echo.
    echo To check if running: Open http://localhost:8080 in browser
    echo To remove: Run uninstall_invisible.bat
) else (
    echo ERROR: Failed to add registry entry
    echo Make sure you are running as Administrator
)

echo.
echo Installation complete!
pause