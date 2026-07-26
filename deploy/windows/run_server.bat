@echo off
REM BridgeWebCamera - duoc goi boi Scheduled Task "BridgeWebCamera" khi logon.
REM Vong lap tu restart khi app thoat/crash. KHONG tu dong pull code.
cd /d "%~dp0..\.."
set PYTHONUTF8=1

:loop
"venv\Scripts\python.exe" main_api_cam.py >> app.log 2>&1
echo [%date% %time%] server exited with code %errorlevel%, restarting in 10s >> app.log
timeout /t 10 /nobreak >nul
goto loop
