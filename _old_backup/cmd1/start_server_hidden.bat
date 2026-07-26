@echo off
REM Completely hidden startup script for Face Recognition Server
REM This script starts the application with NO visible windows at all

setlocal EnableDelayedExpansion

REM Get the directory where this script is located
set "SCRIPT_DIR=%~dp0"
set "PROJECT_DIR=%SCRIPT_DIR%.."

REM Change to project directory
cd /d "%PROJECT_DIR%"

echo ---------------------------------------------------
echo [INFO] Bat dau kiem tra cap nhat...

REM 3. --- PHAN GIT UPDATE ---
if exist ".git" (
    REM Dam bao Git luon dung duong dan SSH cua ban
    git remote set-url origin git@github.com:CromBorw2e36/BridgeWebCameraPublic.git
    
    REM Huy bo thay doi cuc bo (Force Reset)
    echo [INFO] Resetting local changes...
    git reset --hard HEAD
    
    REM Tai code moi
    echo [UPDATE] Pulling latest code from GitHub...
    git pull origin main
    
    echo [INFO] Update code completed.
) else (
    echo [INFO] Creating new Git repository
    git init
    git remote add origin git@github.com:CromBorw2e36/BridgeWebCameraPublic.git
    git reset --hard HEAD
    git pull origin main
)
echo ---------------------------------------------------
echo [INFO] Starting Face Recognition Server silently...
REM Check if main file exists
if not exist "main_api_cam.py" (
    exit /b 1
)

REM Start application completely hidden using pythonw (no console window)
pythonw main_api_cam.py

REM Exit silently
exit /b 0