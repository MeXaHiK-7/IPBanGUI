@echo off
title IPBan Control Center Launcher
cd /d "%~dp0"

:: Якщо існує скомпільований exe-лаунчер, запускаємо його безпосередньо
if exist "%~dp0IPBanControlCenter.exe" (
    start "" "%~dp0IPBanControlCenter.exe"
    exit /b
)

:: Перевірка наявності прав адміністратора
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [INFO] Запит прав Адміністратора для керування службою IPBan та брандмауером...
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process powershell.exe -ArgumentList '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""%~dp0IPBanGUI.ps1""' -WorkingDirectory ""%~dp0"" -Verb RunAs"
    exit /b
)

:: Запуск безпосередньо через PowerShell
powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0IPBanGUI.ps1"
