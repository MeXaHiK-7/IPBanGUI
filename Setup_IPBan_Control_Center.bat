@echo off
title Встановлення IPBan Manager & Control Center
chcp 65001 >nul

:: Перевірка прав адміністратора
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Запит прав адміністратора...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process cmd -ArgumentList '/c \"\"%~f0\"\"' -Verb RunAs"
    exit /b
)

cd /d "%~dp0"

:: Якщо існує скомпільований exe-інсталятор, запускаємо його
if exist "%~dp0Setup_IPBanGUI.exe" (
    start "" "%~dp0Setup_IPBanGUI.exe"
    exit /b
)

:: Інакше запускаємо через PowerShell
powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0Installer.ps1"
exit /b
