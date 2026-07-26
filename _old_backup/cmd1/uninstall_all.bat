@echo off
REM Uninstall all auto-start methods for Face Recognition Server

setlocal EnableDelayedExpansion

echo ========================================
echo Face Recognition Server Auto-Start Removal
echo ========================================
echo.

set "SCRIPT_DIR=%~dp0"

echo Removing all auto-start methods...
echo.

echo 1/5: Removing Invisible Mode...
if exist "%SCRIPT_DIR%uninstall_invisible.bat" call "%SCRIPT_DIR%uninstall_invisible.bat"
echo.

echo 2/5: Removing Registry Startup...
if exist "%SCRIPT_DIR%uninstall_registry.bat" call "%SCRIPT_DIR%uninstall_registry.bat"
echo.

echo 3/5: Removing User Startup Folder...
if exist "%SCRIPT_DIR%uninstall_startup.bat" call "%SCRIPT_DIR%uninstall_startup.bat"
echo.

echo 4/5: Removing Windows Service...
if exist "%SCRIPT_DIR%uninstall_service_improved.bat" call "%SCRIPT_DIR%uninstall_service_improved.bat"
echo.

echo 5/5: Removing Scheduled Task...
if exist "%SCRIPT_DIR%uninstall_task.bat" call "%SCRIPT_DIR%uninstall_task.bat"
echo.

echo ========================================
echo Removal Complete!
echo ========================================
echo.
echo All auto-start methods have been removed.
echo The Face Recognition Server will no longer start automatically.
echo.
pause