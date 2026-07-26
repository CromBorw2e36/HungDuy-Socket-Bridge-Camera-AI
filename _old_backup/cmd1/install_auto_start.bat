@echo off
REM Comprehensive Auto-Start Installation for Face Recognition Server
REM This script tries multiple methods to ensure the server starts on boot

setlocal EnableDelayedExpansion

echo ========================================
echo Face Recognition Server Auto-Start Setup
echo ========================================
echo.

set "SCRIPT_DIR=%~dp0"

echo Available installation methods:
echo.
echo 1. INVISIBLE MODE (Recommended - Requires Admin)
echo    - Completely hidden, NO windows ever shown
echo    - Uses VBScript for maximum stealth
echo    - Starts for all users when Windows boots
echo.
echo 2. Registry Startup (Requires Admin)
echo    - Minimal window visibility
echo    - Most reliable method
echo.
echo 3. User Startup Folder (No Admin Required)
echo    - Starts when current user logs in
echo    - Easy to install/uninstall
echo.
echo 4. Windows Service (Advanced - Requires Admin + pywin32)
echo    - Runs as system service
echo    - Most professional but requires Python packages
echo.
echo 5. Scheduled Task (Requires Admin)
echo    - Uses Windows Task Scheduler
echo    - Can be unreliable
echo.
echo 6. Install All Methods (Maximum Reliability)
echo.

set /p "choice=Enter your choice (1-6): "

if "%choice%"=="1" goto :invisible
if "%choice%"=="2" goto :registry
if "%choice%"=="3" goto :startup
if "%choice%"=="4" goto :service
if "%choice%"=="5" goto :task
if "%choice%"=="6" goto :all
echo Invalid choice. Exiting.
pause
exit /b 1

:invisible
echo.
echo Installing Invisible Mode (VBScript)...
call "%SCRIPT_DIR%install_invisible.bat"
goto :end

:registry
echo.
echo Installing Registry Startup Method...
call "%SCRIPT_DIR%install_registry.bat"
goto :end

:startup
echo.
echo Installing User Startup Folder Method...
call "%SCRIPT_DIR%install_startup.bat"
goto :end

:service
echo.
echo Installing Windows Service Method...
call "%SCRIPT_DIR%install_service_improved.bat"
goto :end

:task
echo.
echo Installing Scheduled Task Method...
call "%SCRIPT_DIR%install_task.bat"
goto :end

:all
echo.
echo Installing ALL methods for maximum reliability...
echo.

echo 1/5: Installing Invisible Mode...
call "%SCRIPT_DIR%install_invisible.bat"
echo.

echo 2/5: Installing Registry Startup...
call "%SCRIPT_DIR%install_registry.bat"
echo.

echo 3/5: Installing User Startup Folder...
call "%SCRIPT_DIR%install_startup.bat"
echo.

echo 4/5: Installing Windows Service...
call "%SCRIPT_DIR%install_service_improved.bat"
echo.

echo 5/5: Installing Scheduled Task...
call "%SCRIPT_DIR%install_task.bat"
echo.

echo ✓ All installation methods completed!
echo The Face Recognition Server should now start automatically using multiple methods.

:end
echo.
echo ========================================
echo Installation Complete!
echo ========================================
echo.
echo To test: Restart your computer and check if the server starts automatically.
echo To uninstall: Run the corresponding uninstall_*.bat files.
echo.
pause