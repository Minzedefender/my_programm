chcp 65001 >nul
@echo off
setlocal
set SCRIPT_DIR=%~dp0
set PS_SCRIPT=%SCRIPT_DIR%setup\SetupWizard.ps1

echo.
echo [INFO] Запуск мастер-настройки базы...
echo.

powershell -NoLogo -NoExit -ExecutionPolicy Bypass -File "%PS_SCRIPT%"
