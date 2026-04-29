@echo off
echo Check disk all [v1.5.0]
echo _BrightDarkness_
echo.

:: Enable delayed expansion for dynamic variable updates in loop
setlocal EnableDelayedExpansion

:: Initialize
set "workdir=%tmp%"
set "cleanup=0"
set "totalvolume=0"
set "currentvolume=0"

::Parameter
if /i "%1"=="-help" (
    echo -help          Show this Help Page
    echo -log           Show latest logs and location
    echo -cleanup       Clean temporary files
    echo -clear [-q]    Removes all log files [Quiet mode (Command executes immediately^)]
    echo -select        Select volumes to chkdsk on
    exit /b
)

:: Show log files and location. If no log files exist, show message and exit.
if /i "%1"=="-log" (
    echo !workdir!
    powershell -Command "gci !workdir! -Filter "chkdskAlog_*.txt" | Select-Object LastWriteTime,Length,Name"
    exit /b
)

:: Cleanup temporary files. This is useful if the script was forcefully exited and left temporary files behind, or to just clean up before next execution. Temporary files are deleted at the start and end of the script, but this allows users to clean up in between if needed.
if /i "%1"=="-cleanup" (
    call :cleanup
    del !workdir!\tmpchkdskA_DevicesSelect >nul 2>&1
    exit /b
)

:: List log files and confirm before deletion. If -q is provided, skip confirmation and delete immediately.
if /i "%1"=="-clear" (
    for %%f in (!workdir!\chkdskAlog_*.txt) do (
        echo - %%~nxf
    )
    if not exist !workdir!\chkdskAlog_*.txt (
        echo No logs exist
        exit /b
    )

    if /i "%2"=="-q" (
        echo -q detected.
        goto :clearConfirm
    ) else (
        echo Are you sure you want to remove these log files?
        echo.
        set /p "clearConfirm=Type YES to confirm: "
        if /i "!clearConfirm!"=="YES" (
            :clearConfirm
            del !workdir!\chkdskAlog_*.txt /q
            echo Logs removed.
        )
    )
    exit /b
)

:: Validate selected volumes and write to temporary file
:: Used persist_chkdskA_DevicesSelect.tmp as a temporary file to store valid selected volumes. Temporary file is not affected by cleanup function and is deleted immediately after use.
:: File will remain if user forecefully exists the script after UAC escalation. It will be used for next execution or can be deleted manually or with -cleanup parameter.
if /i "%1"=="-select" (
    echo -select detected. Please select volumes to chkdsk:
    call :get_devices
    echo Volumes:
    type "!workdir!\chkdskA_Devices.tmp"
    echo.
    set /p "selectedVolumes=Enter volumes to chkdsk (separated by space, e.g., C: D:): "
    > "!workdir!\persist_chkdskA_DevicesSelect.tmp" (
        for %%v in (!selectedVolumes!) do (
            if exist %%v\ (
                set "seenValidVolumes=1"
                echo %%v
            )
        )
    )
    if not defined seenValidVolumes (
        echo No valid volumes selected. Exiting.
        del "!workdir!\persist_chkdskA_DevicesSelect.tmp" >nul 2>&1
        exit /b
    )
    goto :startOfProgram
)

:: If any parameter is provided that is not recognized, show error and exit
if not "%1"=="" (
    echo Invalid parameter. Use -help for available parameters.
    exit /b
)


:: Start of program after parameter handling if not exited
:startOfProgram

:: Check for elevated privileges
net session >nul 2>&1
if !errorLevel! NEQ 0 (
    call :UACescalation
    exit /b
)

:: Get timestamp with Subscript
call :get_timestamp

:: Cleanup temporary files with Subscript
call :cleanup

:: Getting Volumes to chkdsk on and writing to log
if not exist "!workdir!\persist_chkdskA_DevicesSelect.tmp" (
    call :get_devices
) else (
    echo Using selected volumes
    copy "!workdir!\persist_chkdskA_DevicesSelect.tmp" "!workdir!\chkdskA_Devices.tmp" >nul
    del "!workdir!\persist_chkdskA_DevicesSelect.tmp" >nul
)

for /F %%x in (!workdir!\chkdskA_Devices.tmp) do (
    set /a "totalvolume+=1"
)
echo Done^^!
echo.

:: Chkdsking the Volumes and writing to log
for /F %%x in (!workdir!\chkdskA_Devices.tmp) do (
    echo Processing %%x
    (
        echo.
        echo ###################################### %%x ######################################
        echo.
        :: Run chkdsk and save output to a temporary file for each volume
        chkdsk %%x
    ) >> "!workdir!\chkdskA_Result.tmp"
    
    :: Log error level for each volume
    echo %%x !errorLevel! >> "!workdir!\chkdskA_VolumeErrors.tmp"
    set /a "currentvolume+=1"
    echo %%x Done^^! (!currentvolume!/!totalvolume!^)
)
echo.

:: Assemble final log
> "!workdir!\chkdskAlog_!timestamp!.txt" (
    echo Volumes to check:
    type "!workdir!\chkdskA_VolumeErrors.tmp"
    type "!workdir!\chkdskA_Result.tmp"
)

:: Opening the log
echo Simplified results:
type "!workdir!\chkdskA_VolumeErrors.tmp"
echo Done^^!
echo.
echo Log: !workdir!\chkdskAlog_!timestamp!.txt
echo.

:: Clears temporary files before concluding script
call :cleanup
echo.

:end
endlocal
pause
exit /b
:: End of script

:: Subsections
:get_timestamp
echo Getting timestamp...
:: Get the current date and time in a standardized format (YYYY.MM.DD.hh.mm.ss)
for /f "delims=" %%a in ('powershell -command "Get-Date -Format 'yyyy.MM.dd.HH.mm.ss'"') do set "timestamp=%%a"
goto :eof

:cleanup
echo Cleaning temporary files...
for %%f in (!workdir!\chkdskA_*.tmp) do (
    if exist "%%f" del "%%f"
)
goto :eof

:get_devices
echo Getting volumes...
powershell -command "Get-CimInstance Win32_LogicalDisk | Select-Object DeviceID" | find ":" > "!workdir!\chkdskA_Devices.tmp"
goto :eof

:UACescalation
ECHO **************************************
ECHO Invoking UAC for Privilege Escalation
ECHO **************************************
if exist "!LocalAppData!\Microsoft\WindowsApps\wt.exe" (
    powershell -Command "Start-Process wt.exe -ArgumentList 'cmd /c \"%~f0\"' -Verb RunAs"
) else (
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
)
goto :eof