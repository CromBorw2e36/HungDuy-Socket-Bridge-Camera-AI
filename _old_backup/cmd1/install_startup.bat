@echo off
REM Install Face Recognition Server to Windows Startup Folder
REM This method is more reliable than scheduled tasks

setlocal EnableDelayedExpansion

set "SCRIPT_DIR=%~dp0"
set "START_SCRIPT=%SCRIPT_DIR%start_server_hidden.bat"
set "STARTUP_FOLDER=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup"
set "SHORTCUT_NAME=Face Recognition Server.bat"

echo Installing Face Recognition Server to Windows Startup...
echo Script: %START_SCRIPT%
echo Startup Folder: %STARTUP_FOLDER%

REM Check if start script exists
if not exist "%START_SCRIPT%" (
    echo ERROR: Start script not found: %START_SCRIPT%
    pause
    exit /b 1
)

REM Create startup folder if it doesn't exist
if not exist "%STARTUP_FOLDER%" (
    mkdir "%STARTUP_FOLDER%"
)

REM Remove existing startup file
if exist "%STARTUP_FOLDER%\%SHORTCUT_NAME%" (
    del "%STARTUP_FOLDER%\%SHORTCUT_NAME%"
    echo Removed existing startup file
)

REM Copy the start script to startup folder
copy "%START_SCRIPT%" "%STARTUP_FOLDER%\%SHORTCUT_NAME%"

if %ERRORLEVEL%==0 (
    echo ✓ Face Recognition Server added to Windows Startup
    echo.
    echo The server will start automatically when you log in to Windows.
    echo.
    echo To remove from startup, delete:
    echo "%STARTUP_FOLDER%\%SHORTCUT_NAME%"
    echo.
    echo Or run: uninstall_startup.bat
) else (
    echo ERROR: Failed to copy startup file
)

echo.
echo Installation complete!
pause