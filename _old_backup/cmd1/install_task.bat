@echo off
REM Task Scheduler installation for Face Recognition Server
REM This creates a scheduled task to start the server at Windows startup

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
set "TASK_NAME=FaceRecognitionServer"
set "BATCH_FILE=%SCRIPT_DIR%start_server_hidden.bat"

echo Installing Face Recognition Server as Startup Task...
echo Task Name: %TASK_NAME%
echo Batch File: %BATCH_FILE%

REM Check if batch file exists
if not exist "%BATCH_FILE%" (
    echo ERROR: Batch file not found: %BATCH_FILE%
    pause
    exit /b 1
)

REM Delete existing task if it exists
schtasks /delete /tn "%TASK_NAME%" /f >nul 2>&1

REM Create new scheduled task with better parameters
echo Creating scheduled task...
schtasks /create ^
    /tn "%TASK_NAME%" ^
    /tr "cmd.exe /c \"\"%BATCH_FILE%\"\"" ^
    /sc onlogon ^
    /ru "%USERNAME%" ^
    /rl highest ^
    /delay 0000:30 ^
    /f

if %ERRORLEVEL%==0 (
    echo ✓ Scheduled task created successfully
    echo.
    echo The Face Recognition Server will now start automatically when Windows boots.
    echo.
    echo Task Management Commands:
    echo   Run now:  schtasks /run /tn "%TASK_NAME%"
    echo   Stop:     taskkill /f /im python.exe
    echo   Query:    schtasks /query /tn "%TASK_NAME%"
    echo   Delete:   schtasks /delete /tn "%TASK_NAME%" /f
) else (
    echo ERROR: Failed to create scheduled task
)

echo.
echo Installation complete!
pause