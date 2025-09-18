chcp 65001 >nul
@echo off
setlocal
set SCRIPT_DIR=%~dp0
set PS_SCRIPT=%SCRIPT_DIR%Run-Backup.ps1

echo.
echo [INFO] Запуск процесса резервного копирования...
echo.

powershell -NoLogo -NoExit -ExecutionPolicy Bypass -File "%PS_SCRIPT%" %*
