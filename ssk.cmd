@echo off
setlocal enabledelayedexpansion

rem ssk.cmd
rem SSH key installer with host management.
rem
rem Usage:
rem   ssk                              - interactive host selection
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

rem Default: interactive mode when no args, direct connect otherwise
if "%~1"=="" (
    call :do_connect
    exit /b !errorlevel!
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%save-ssh-key.ps1" %ARGS%

if errorlevel 1 (
    echo.
    echo Script exited with an error. Press any key to close...
    pause >nul
)

exit /b 0

:do_list
    if not exist "%CONFIG%" (
        echo No hosts saved yet.
        exit /b 0
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
        echo No hosts saved yet.
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
        echo No hosts saved yet.
        exit /b 0
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

:do_connect
    call :do_list
    echo.
    echo Type /help for available commands, /q to quit.
    echo.
    set "DEBUG_ARG="
    if not "!PS_DEBUG!"=="" set "DEBUG_ARG=--debug"

:connect_loop
    set "INPUT="
    set /p "INPUT=ssk> "
    if not defined INPUT (
        echo.
        goto :eof
    )

    rem --- / prefix commands ---
    set "CMD=!INPUT:~0,1!"
    if not "!CMD!"=="/" goto :do_connect_default

    for /f "tokens=1,* delims= " %%c in ("!INPUT!") do (
        set "CMD_NAME=%%c"
        set "CMD_ARGS=%%d"
    )

    if /i "!CMD_NAME!"=="/q" goto :eof
    if /i "!CMD_NAME!"=="/quit" goto :eof
    if /i "!CMD_NAME!"=="/exit" goto :eof
    if /i "!CMD_NAME!"=="/list" (
        call :do_list
        echo.
        goto :connect_loop
    )
    if /i "!CMD_NAME!"=="/ls" (
        call :do_list
        echo.
        goto :connect_loop
    )
    if /i "!CMD_NAME!"=="/del" (
        call :do_del_by_id !CMD_ARGS!
        if !errorlevel!==0 (
            call :do_list
            echo.
        )
        goto :connect_loop
    )
    if /i "!CMD_NAME!"=="/rm" (
        call :do_del_by_id !CMD_ARGS!
        if !errorlevel!==0 (
            call :do_list
            echo.
        )
        goto :connect_loop
    )
    if /i "!CMD_NAME!"=="/rename" (
        set "RN_ID="
        set "RN_NEW="
        for /f "tokens=1,*" %%x in ("!CMD_ARGS!") do (
            set "RN_ID=%%x"
            set "RN_NEW=%%y"
        )
        call :do_rename_cmd
        if !errorlevel!==0 (
            call :do_list
            echo.
        )
        goto :connect_loop
    )
    if /i "!CMD_NAME!"=="/add" (
        call :do_add "!CMD_ARGS!"
        if !errorlevel!==0 (
            call :do_list
            echo.
        )
        goto :connect_loop
    )
    if /i "!CMD_NAME!"=="/filter" (
        call :do_filter "!CMD_ARGS!"
        echo.
        goto :connect_loop
    )
    if /i "!CMD_NAME!"=="/fi" (
        call :do_filter "!CMD_ARGS!"
        echo.
        goto :connect_loop
    )
    if /i "!CMD_NAME!"=="/clear" (
        cls
        goto :connect_loop
    )
    if /i "!CMD_NAME!"=="/help" goto :show_help
    if /i "!CMD_NAME!"=="/h" goto :show_help
    if "!CMD_NAME!"=="/" goto :show_help

    echo Unknown command: !CMD_NAME!
    echo Type /help for available commands.
    echo.
    goto :connect_loop

:do_connect_default
    echo !INPUT!| findstr /rx "[0-9][0-9]*" >nul 2>&1
    if !errorlevel!==0 (
        call :do_get_alias !INPUT!
        if errorlevel 1 (
            echo Invalid selection: !INPUT!
            echo.
            goto :connect_loop
        )
        echo Connecting to !TARGET_ALIAS!...
        call "%~f0" "!TARGET_ALIAS!" !DEBUG_ARG!
    ) else (
        echo Connecting to !INPUT!...
        call "%~f0" "!INPUT!" !DEBUG_ARG!
    )

    echo.
    goto :connect_loop

:do_del_by_id
    set "DEL_ID=%~1"
    if "%DEL_ID%"=="" (
        echo Usage: /del ^<number^>
        exit /b 1
    )
    if not exist "%CONFIG%" (
        echo No hosts saved yet.
        exit /b 0
    )

    set "HOST_NAME="
    set "IDX=0"
    set "TARGET_ALIAS="

    for /f "usebackq tokens=1,2,* delims= " %%a in ("%CONFIG%") do (
        if /i "%%a"=="Host" (
            if defined HOST_NAME (
                set /a IDX+=1
                if !IDX!==%DEL_ID% (
                    set "TARGET_ALIAS=!HOST_NAME!"
                )
            )
            set "HOST_NAME=%%b"
        )
    )
    if defined HOST_NAME (
        set /a IDX+=1
        if !IDX!==%DEL_ID% (
            set "TARGET_ALIAS=%HOST_NAME%"
        )
    )

    if not defined TARGET_ALIAS (
        echo Host not found for id: %DEL_ID%
        exit /b 1
    )

    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
        "$f='%CONFIG%'; $c=Get-Content $f; $out=@(); $skip=$false; foreach($l in $c){ if($l -match '^\s*Host\s+'+$([regex]::Escape('%TARGET_ALIAS%'))+'\s*$'){ $skip=$true; continue } if($skip -and $l -match '^\s+'){ continue } if($skip){ $skip=$false }; if(-not $skip){ $out += $l } }; Set-Content $f ($out -join \"`n\") -NoNewline; Write-Host 'Deleted: %TARGET_ALIAS%'"

    exit /b %errorlevel%

:do_rename_cmd
    if not defined RN_ID (
        echo Usage: /rename ^<number^> ^<new-alias^>
        exit /b 1
    )
    if not defined RN_NEW (
        echo Usage: /rename ^<number^> ^<new-alias^>
        exit /b 1
    )

    call :do_get_alias "!RN_ID!"
    if errorlevel 1 exit /b 1

    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
        "$f='%CONFIG%'; $c=Get-Content $f -Raw; $esc=[regex]::Escape('!TARGET_ALIAS!'); $old='(?m)^Host\s+'+$esc+'\s*$'; $new='Host !RN_NEW!'; if($c -match $old){ $c=[regex]::Replace($c,$old,$new); Set-Content $f $c -NoNewline; Write-Host 'Renamed: !TARGET_ALIAS! -> !RN_NEW!' } else { Write-Host 'Host alias not found: !TARGET_ALIAS!'; exit 1 }"

    exit /b %errorlevel%

:do_rename_by_id
    set "RN_ID=%~1"
    set "RN_NEW=%~2"
    if "%RN_ID%"=="" (
        echo Usage: /rename ^<number^> ^<new-alias^>
        exit /b 1
    )
    if "%RN_NEW%"=="" (
        echo Usage: /rename ^<number^> ^<new-alias^>
        exit /b 1
    )

    call :do_get_alias %RN_ID%
    if errorlevel 1 exit /b 1

    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
        "$f='%CONFIG%'; $c=Get-Content $f -Raw; $esc=[regex]::Escape('!TARGET_ALIAS!'); $old='(?m)^Host\s+'+$esc+'\s*$'; $new='Host %RN_NEW%'; if($c -match $old){ $c=[regex]::Replace($c,$old,$new); Set-Content $f $c -NoNewline; Write-Host 'Renamed: !TARGET_ALIAS! -> %RN_NEW%' } else { Write-Host 'Host alias not found: !TARGET_ALIAS!'; exit 1 }"

    exit /b %errorlevel%

:do_add
    set "ADD_TARGET=%~1"
    if "%ADD_TARGET%"=="" (
        echo Usage: /add user@host:port
        exit /b 1
    )

    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
        "$t='%ADD_TARGET%'; $u='root'; $h=$t; $p='22';" ^
        "if($t -match '^([^@]+)@([^:]+):(\d+)$'){$u=$Matches[1];$h=$Matches[2];$p=$Matches[3]}" ^
        "elseif($t -match '^([^@]+)@([^:]+)$'){$u=$Matches[1];$h=$Matches[2]}" ^
        "elseif($t -match '^([^:]+):(\d+)$'){$h=$Matches[1];$p=$Matches[2]};" ^
        "$alias=$t; $f=Join-Path $env:USERPROFILE '.ssh\config'; $dup=$false;" ^
        "if(Test-Path $f){" ^
        "$raw=Get-Content $f -Raw;" ^
        "if($raw -like ('*Host ' + $alias + '*HostName ' + $h + '*')){$dup=$true}" ^
        "};" ^
        "if($dup){Write-Host ('Already exists: ' + $alias)}" ^
        "else{" ^
        "$d=Get-Date -Format 'yyyy-MM-dd';" ^
        "$nl=[char]10;" ^
        "$e=$nl + '# Added by ssk - ' + $d + $nl + 'Host ' + $alias + $nl + '    HostName ' + $h + $nl + '    User ' + $u + $nl + '    Port ' + $p + $nl;" ^
        "if(-not(Test-Path $f)){New-Item -ItemType File -Path $f -Force | Out-Null};" ^
        "Add-Content $f $e -NoNewline;" ^
        "Write-Host ('Added: ' + $alias)" ^
        "}"

    exit /b %errorlevel%

:do_filter
    set "FILTER_KEY=%~1"
    if "%FILTER_KEY%"=="" (
        call :do_list
        exit /b 0
    )
    if not exist "%CONFIG%" (
        echo No hosts saved yet.
        exit /b 0
    )

    set "HOST_NAME="
    set "HOST_ADDR="
    set "USER_NAME="
    set "PORT="
    set "IDX=0"

    for /f "usebackq tokens=1,2,* delims= " %%a in ("%CONFIG%") do (
        if /i "%%a"=="Host" (
            if defined HOST_NAME call :print_entry_filtered
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
    if defined HOST_NAME call :print_entry_filtered
    goto :eof

:print_entry_filtered
    set /a IDX+=1
    if not defined HOST_ADDR set "HOST_ADDR=%HOST_NAME%"
    if not defined USER_NAME set "USER_NAME=root"
    if not defined PORT set "PORT=22"
    set "ENTRY=%USER_NAME%@%HOST_ADDR%:%PORT%  [%HOST_NAME%]"
    echo !ENTRY! | findstr /i /c:"%FILTER_KEY%" >nul 2>&1
    if !errorlevel!==0 echo %IDX%  !ENTRY!
    goto :eof

:show_help
    echo.
    echo Available commands:
    echo   /ls  /list           Show host list
    echo   /del ^<number^>        Delete host by list number
    echo   /rename ^<n^> ^<name^>   Rename host alias by list number
    echo   /add ^<user@host^>     Save a new host to config
    echo   /filter ^<keyword^>    Filter list by keyword
    echo   /clear               Clear screen
    echo   /help  /h            Show this help
    echo   /q  /quit  /exit     Quit interactive mode
    echo.
    echo   ^<number^>             Connect to host by list number
    echo   ^<string^>             Connect by user@host:port or host alias
    echo.
    goto :connect_loop
