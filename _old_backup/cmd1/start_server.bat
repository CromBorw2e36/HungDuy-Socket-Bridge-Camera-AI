@echo off
REM Simple startup script for Face Recognition Server
REM This script starts the application directly

setlocal EnableDelayedExpansion

REM 1. Lay duong dan hien tai
set "SCRIPT_DIR=%~dp0"
set "PROJECT_DIR=%SCRIPT_DIR%.."

echo Starting Face Recognition Server...
echo Project Directory: %PROJECT_DIR%

REM 2. Di chuyen den thu muc project
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

REM 4. Kiem tra file chay chinh
if not exist "main_api_cam.py" (
    echo ERROR: main_api_cam.py not found in %PROJECT_DIR%
    pause
    exit /b 1
)

echo [INFO] Starting Face Recognition Server silently...
REM Chay python thong thuong (hien cua so) de theo doi log
python main_api_cam.py

REM If we get here, the application has stopped
echo Application has stopped.
pause