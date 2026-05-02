@echo off
setlocal enabledelayedexpansion

rem ssk.cmd
rem SSH key installer with host management.
rem
rem Usage:
rem   ssk                              - connect (prompt for host)
rem   ssk user@host:port               - connect to host
rem   ssk --id N                       - connect to Nth saved host
rem   ssk list                         - list saved hosts
rem   ssk list rename <old> <new>      - rename a host alias
rem   ssk --debug ...                  - verbose output

set "SCRIPT_DIR=%~dp0"
set "CONFIG=%USERPROFILE%\.ssh\config"
set "PS_DEBUG="

rem Check for --debug in any argument
for %%i in (%*) do (
    if "%%i"=="--debug" set "PS_DEBUG=-Debug"
)

rem Strip --debug from args for dispatch
set "ARGS="
for %%i in (%*) do (
    if not "%%i"=="--debug" set "ARGS=!ARGS! %%i"
)

rem Dispatch subcommands
if /i "%~1"=="list" (
    if /i "%~2"=="rename" (
        call :do_rename "%~3" "%~4"
    ) else (
        call :do_list
    )
    exit /b !errorlevel!
)

rem Handle --id N
if "%~1"=="--id" (
    call :do_get_alias %~2
    if errorlevel 1 exit /b 1
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%save-ssh-key.ps1" "!TARGET_ALIAS!" %PS_DEBUG%
    if errorlevel 1 (
        echo.
        echo Script exited with an error. Press any key to close...
        pause >nul
    )
    exit /b 0
)

rem Default: connect to host
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%save-ssh-key.ps1" %ARGS%

if errorlevel 1 (
    echo.
    echo Script exited with an error. Press any key to close...
    pause >nul
)

exit /b 0

:do_list
    if not exist "%CONFIG%" (
        echo No SSH config found at %CONFIG%
        exit /b 1
    )

    set "HOST_NAME="
    set "HOST_ADDR="
    set "USER_NAME="
    set "PORT="
    set "IDX=0"

    for /f "usebackq tokens=1,2,* delims= " %%a in ("%CONFIG%") do (
        if /i "%%a"=="Host" (
            if defined HOST_NAME call :print_entry
            set "HOST_NAME=%%b"
            set "HOST_ADDR="
            set "USER_NAME="
            set "PORT="
        ) else if /i "%%a"=="HostName" (
            set "HOST_ADDR=%%b"
        ) else if /i "%%a"=="User" (
            set "USER_NAME=%%b"
        ) else if /i "%%a"=="Port" (
            set "PORT=%%b"
        )
    )
    if defined HOST_NAME call :print_entry
    goto :eof

:print_entry
    set /a IDX+=1
    if not defined HOST_ADDR set "HOST_ADDR=%HOST_NAME%"
    if not defined USER_NAME set "USER_NAME=root"
    if not defined PORT set "PORT=22"
    echo %IDX%  %USER_NAME%@%HOST_ADDR%:%PORT%  [%HOST_NAME%]
    goto :eof

:do_get_alias
    set "TARGET_ID=%~1"
    if "%TARGET_ID%"=="" (
        echo Usage: ssk --id ^<number^>
        exit /b 1
    )

    if not exist "%CONFIG%" (
        echo No SSH config found at %CONFIG%
        exit /b 1
    )

    set "HOST_NAME="
    set "IDX=0"

    for /f "usebackq tokens=1,2,* delims= " %%a in ("%CONFIG%") do (
        if /i "%%a"=="Host" (
            if defined HOST_NAME (
                set /a IDX+=1
                if !IDX!==%TARGET_ID% (
                    set "TARGET_ALIAS=!HOST_NAME!"
                    goto :eof
                )
            )
            set "HOST_NAME=%%b"
        )
    )
    if defined HOST_NAME (
        set /a IDX+=1
        if !IDX!==%TARGET_ID% (
            set "TARGET_ALIAS=%HOST_NAME%"
            goto :eof
        )
    )
    echo Host not found for id: %TARGET_ID%
    exit /b 1

:do_rename
    set "OLD_ALIAS=%~1"
    set "NEW_ALIAS=%~2"

    if not exist "%CONFIG%" (
        echo No SSH config found at %CONFIG%
        exit /b 1
    )
    if "%OLD_ALIAS%"=="" (
        echo Usage: ssk list rename ^<old-alias^> ^<new-alias^>
        exit /b 1
    )
    if "%NEW_ALIAS%"=="" (
        echo Usage: ssk list rename ^<old-alias^> ^<new-alias^>
        exit /b 1
    )

    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
        "$f='%CONFIG%'; $c=Get-Content $f -Raw; $esc=[regex]::Escape('%OLD_ALIAS%'); $old='(?m)^Host\s+'+$esc+'\s*$'; $new='Host %NEW_ALIAS%'; if($c -match $old){ $c=[regex]::Replace($c,$old,$new); Set-Content $f $c -NoNewline; Write-Host 'Renamed: %OLD_ALIAS% -> %NEW_ALIAS%' } else { Write-Host 'Host alias not found: %OLD_ALIAS%'; exit 1 }"

    exit /b %errorlevel%
