@echo off
REM Improved Windows Service Installation for Face Recognition Server
REM This script installs the Python service wrapper

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
set "PROJECT_DIR=%SCRIPT_DIR%.."
set "SERVICE_SCRIPT=%SCRIPT_DIR%service_wrapper.py"

echo Installing Face Recognition Server as Windows Service...
echo Script Directory: %SCRIPT_DIR%
echo Service Script: %SERVICE_SCRIPT%

REM Check if service script exists
if not exist "%SERVICE_SCRIPT%" (
    echo ERROR: Service script not found: %SERVICE_SCRIPT%
    pause
    exit /b 1
)

REM Change to project directory
cd /d "%PROJECT_DIR%"

REM Install pywin32 if not already installed
echo Checking for pywin32...
python -c "import win32serviceutil" 2>nul
if %ERRORLEVEL% neq 0 (
    echo Installing pywin32...
    python -m pip install pywin32
    if %ERRORLEVEL% neq 0 (
        echo ERROR: Failed to install pywin32
        pause
        exit /b 1
    )
)

REM Stop existing service if running
echo Stopping existing service if running...
sc stop "FaceRecognitionServer" >nul 2>&1

REM Remove existing service if exists
echo Removing existing service if exists...
python "%SERVICE_SCRIPT%" remove >nul 2>&1

REM Install new service
echo Installing new Windows Service...
python "%SERVICE_SCRIPT%" install

if %ERRORLEVEL%==0 (
    echo Service installed successfully
    
    REM Start the service
    echo Starting service...
    sc start "FaceRecognitionServer"
    
    if %ERRORLEVEL%==0 (
        echo ✓ Service installed and started successfully
        echo.
        echo Service Management Commands:
        echo   Start:   sc start "FaceRecognitionServer"
        echo   Stop:    sc stop "FaceRecognitionServer"  
        echo   Query:   sc query "FaceRecognitionServer"
        echo   Remove:  python "%SERVICE_SCRIPT%" remove
        echo.
        echo You can also use Services.msc to manage the service graphically.
    ) else (
        echo WARNING: Service installed but failed to start
        echo Try starting it manually: sc start "FaceRecognitionServer"
    )
) else (
    echo ERROR: Failed to install service
    echo Make sure Python and required packages are installed
)

echo.
echo Installation complete!
pause