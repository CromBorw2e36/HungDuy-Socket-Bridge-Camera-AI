@echo off
REM Installation script for Face Recognition Server as Windows Service
REM This script sets up the service to start automatically on Windows boot

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
set "SERVICE_NAME=FaceRecognitionServer"
set "SERVICE_DISPLAY_NAME=Face Recognition Server"
set "SERVICE_DESCRIPTION=Face Recognition Server for Bridge Web Camera"
set "BATCH_FILE=%SCRIPT_DIR%face_recognition_server.bat"

echo Installing Face Recognition Server as Windows Service...
echo Service Name: %SERVICE_NAME%
echo Batch File: %BATCH_FILE%

REM Check if batch file exists
if not exist "%BATCH_FILE%" (
    echo ERROR: Batch file not found: %BATCH_FILE%
    pause
    exit /b 1
)

REM Stop service if it exists
sc query "%SERVICE_NAME%" >nul 2>&1
if %ERRORLEVEL%==0 (
    echo Stopping existing service...
    sc stop "%SERVICE_NAME%"
    timeout /t 3 /nobreak >nul
)

REM Delete existing service
sc delete "%SERVICE_NAME%" >nul 2>&1

REM Create new service
echo Creating Windows Service...
sc create "%SERVICE_NAME%" ^
    binPath= "\"%BATCH_FILE%\" start" ^
    start= auto ^
    DisplayName= "%SERVICE_DISPLAY_NAME%" ^
    obj= "LocalSystem"

if %ERRORLEVEL%==0 (
    echo Service created successfully
    
    REM Set service description
    sc description "%SERVICE_NAME%" "%SERVICE_DESCRIPTION%"
    
    REM Configure service recovery options
    sc failure "%SERVICE_NAME%" reset= 60 actions= restart/5000/restart/10000/restart/30000
    
    echo Starting service...
    sc start "%SERVICE_NAME%"
    
    if %ERRORLEVEL%==0 (
        echo ✓ Service installed and started successfully
        echo.
        echo Service Management Commands:
        echo   Start:   sc start "%SERVICE_NAME%"
        echo   Stop:    sc stop "%SERVICE_NAME%"
        echo   Query:   sc query "%SERVICE_NAME%"
        echo   Delete:  sc delete "%SERVICE_NAME%"
    ) else (
        echo WARNING: Service created but failed to start
        echo Check the service in Windows Services management console
    )
) else (
    echo ERROR: Failed to create service
    echo Make sure you are running as Administrator
)

echo.
echo Installation complete!
pause