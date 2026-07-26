@echo off
REM Face Recognition Server Startup Script for Windows
REM This script reads configuration from config_windows.txt and starts the main application

setlocal EnableDelayedExpansion

REM Get the directory where this script is located
set "SCRIPT_DIR=%~dp0"
set "PROJECT_DIR=%SCRIPT_DIR%.."
set "CONFIG_FILE=%PROJECT_DIR%\config_windows.txt"

REM Function to log messages
call :log_message "Starting Face Recognition Server..."

REM Check if config file exists
if not exist "%CONFIG_FILE%" (
    call :log_message "ERROR: Configuration file not found at %CONFIG_FILE%"
    pause
    exit /b 1
)

REM Read configuration from file
for /f "usebackq tokens=1,2 delims==" %%a in ("%CONFIG_FILE%") do (
    if "%%a"=="APP_PATH" set "APP_PATH=%%b"
    if "%%a"=="PYTHON_PATH" set "PYTHON_PATH=%%b"
    if "%%a"=="WORK_DIR" set "WORK_DIR=%%b"
    if "%%a"=="LOG_FILE" set "LOG_FILE=%%b"
    if "%%a"=="PROCESS_NAME" set "PROCESS_NAME=%%b"
)

REM Set defaults if not specified
if "%PYTHON_PATH%"=="" set "PYTHON_PATH=pythonw"
if "%WORK_DIR%"=="" set "WORK_DIR=%PROJECT_DIR%"
if "%LOG_FILE%"=="" set "LOG_FILE=%WORK_DIR%\app.log"
if "%PROCESS_NAME%"=="" set "PROCESS_NAME=face_recognition_server"

call :log_message "App Path: %APP_PATH%"
call :log_message "Python Path: %PYTHON_PATH%"
call :log_message "Working Directory: %WORK_DIR%"
call :log_message "Log File: %LOG_FILE%"

REM Check if application file exists
if not exist "%APP_PATH%" (
    call :log_message "ERROR: Application file not found at %APP_PATH%"
    pause
    exit /b 1
)

REM Change to working directory
cd /d "%WORK_DIR%" || (
    call :log_message "ERROR: Cannot change to working directory %WORK_DIR%"
    pause
    exit /b 1
)

REM Handle command line arguments
set "ACTION=%1"
if "%ACTION%"=="" set "ACTION=start"

if /i "%ACTION%"=="start" goto :start_app
if /i "%ACTION%"=="stop" goto :stop_app
if /i "%ACTION%"=="restart" goto :restart_app
if /i "%ACTION%"=="status" goto :check_status
if /i "%ACTION%"=="install" goto :install_service
if /i "%ACTION%"=="uninstall" goto :uninstall_service

echo Usage: %0 {start^|stop^|restart^|status^|install^|uninstall}
echo   start     - Start the Face Recognition Server
echo   stop      - Stop the Face Recognition Server
echo   restart   - Restart the Face Recognition Server
echo   status    - Check if the server is running
echo   install   - Install as Windows Service
echo   uninstall - Uninstall Windows Service
pause
exit /b 1

:start_app
call :log_message "Starting application..."

REM Check if already running
call :is_running
if %ERRORLEVEL%==0 (
    call :log_message "Application is already running"
    goto :end
)

REM Create log directory if it doesn't exist
if not exist "%~dp1" mkdir "%LOG_FILE%\.." 2>nul

REM Start the application
start "Face Recognition Server" /min "%PYTHON_PATH%" "%APP_PATH%"
timeout /t 3 /nobreak >nul

REM Check if process started
call :is_running
if %ERRORLEVEL%==0 (
    call :log_message "Application started successfully"
) else (
    call :log_message "ERROR: Application failed to start"
    pause
    exit /b 1
)
goto :end

:stop_app
call :log_message "Stopping application..."

REM Kill all python processes running the app
taskkill /f /im python.exe /fi "WINDOWTITLE eq Face Recognition Server*" 2>nul
if %ERRORLEVEL%==0 (
    call :log_message "Application stopped"
) else (
    call :log_message "No running application found or failed to stop"
)
goto :end

:restart_app
call :log_message "Restarting application..."
call :stop_app
timeout /t 2 /nobreak >nul
call :start_app
goto :end

:check_status
call :is_running
if %ERRORLEVEL%==0 (
    call :log_message "Application is running"
) else (
    call :log_message "Application is not running"
)
goto :end

:install_service
call :log_message "Installing as Windows Service..."
sc create "FaceRecognitionServer" binPath= "\"%SCRIPT_DIR%face_recognition_server.bat\" start" start= auto
if %ERRORLEVEL%==0 (
    call :log_message "Service installed successfully"
    sc start "FaceRecognitionServer"
) else (
    call :log_message "Failed to install service. Run as Administrator."
)
goto :end

:uninstall_service
call :log_message "Uninstalling Windows Service..."
sc stop "FaceRecognitionServer" 2>nul
sc delete "FaceRecognitionServer"
if %ERRORLEVEL%==0 (
    call :log_message "Service uninstalled successfully"
) else (
    call :log_message "Failed to uninstall service or service not found"
)
goto :end

:is_running
tasklist /fi "IMAGENAME eq python.exe" /fi "WINDOWTITLE eq Face Recognition Server*" 2>nul | find /i "python.exe" >nul
exit /b %ERRORLEVEL%

:log_message
echo [%date% %time%] %~1
if exist "%LOG_FILE%" (
    echo [%date% %time%] %~1 >> "%LOG_FILE%"
)
exit /b

:end
if "%ACTION%"=="start" pause
exit /b 0