@echo off
REM Silent startup script for Face Recognition Server (for auto-start)
REM This script starts the application without showing a console window

setlocal EnableDelayedExpansion

REM Get the directory where this script is located
set "SCRIPT_DIR=%~dp0"
set "PROJECT_DIR=%SCRIPT_DIR%.."

REM Change to project directory
cd /d "%PROJECT_DIR%"

REM Check if main file exists
if not exist "main_api_cam.py" (
    exit /b 1
)

REM Start application completely hidden (no window)
pythonw main_api_cam.py

REM Exit without showing window
exit