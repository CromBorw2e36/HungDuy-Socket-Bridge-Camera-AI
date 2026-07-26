@echo off
REM Remove Face Recognition Server from Windows Startup Folder

setlocal EnableDelayedExpansion

set "STARTUP_FOLDER=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup"
set "SHORTCUT_NAME=Face Recognition Server.bat"

echo Removing Face Recognition Server from Windows Startup...

if exist "%STARTUP_FOLDER%\%SHORTCUT_NAME%" (
    del "%STARTUP_FOLDER%\%SHORTCUT_NAME%"
    echo ✓ Face Recognition Server removed from Windows Startup
) else (
    echo Face Recognition Server was not found in startup folder
)

echo.
echo Removal complete!
pause