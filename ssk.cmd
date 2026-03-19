@echo off
:: ssk.cmd
:: Windows batch wrapper for save-ssh-key.ps1
:: Supports double-click or command-line invocation.
::
:: Usage:
::   ssk.cmd
::   ssk.cmd root@192.168.1.1
::   ssk.cmd root@192.168.1.1:2222
::   ssk.cmd 192.168.1.1
::   ssk.cmd 192.168.1.1:2222

setlocal

:: Resolve script directory so it works from any working directory
set "SCRIPT_DIR=%~dp0"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%save-ssh-key.ps1" %*

if errorlevel 1 (
    echo.
    echo Script exited with an error. Press any key to close...
    pause >nul
)

endlocal
