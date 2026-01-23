@echo off
echo Check disk all [v1.4]
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
    exit /b
)

if /i "%1"=="-log" (
    echo !workdir!
    powershell -Command "gci !workdir! -Filter "chkdskA*.txt" | Select-Object LastWriteTime,Length,Name"
    exit /b
)

if /i "%1"=="-cleanup" (
    call :cleanup
    exit /b
)

if /i "%1"=="-clear" (
    dir !workdir!\chkdskA*.txt /b
    if "!errorLevel!"=="1" (
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
            del !workdir!\chkdskA*.txt /q
            echo Logs removed.
        )
    )
    exit /b
)

:: Check for elevated privileges
net session >nul 2>&1
if !errorLevel! NEQ 0 (
    ECHO **************************************
    ECHO Invoking UAC for Privilege Escalation
    ECHO **************************************
    if exist "!LocalAppData!\Microsoft\WindowsApps\wt.exe" (
        powershell -Command "Start-Process wt.exe -ArgumentList 'cmd /c \"%~f0\"' -Verb RunAs"
    ) else (
        powershell -Command "Start-Process '%~f0' -Verb RunAs"
    )
    exit /b
)
pause
:: Get timestamp with Subscript
call :get_timestamp

:: Cleanup temporary files with Subscript
call :cleanup

:: Getting Volumes to chkdsk on and writing to log
echo Volumes to check: >> "!workdir!\chkdskAvolumes"
echo Getting volumes...
powershell -command "Get-CimInstance Win32_LogicalDisk | Select-Object DeviceID" | find ":" > "!workdir!\chkdskA"
for /F %%x in (!workdir!\chkdskA) do (
    set /a "totalvolume+=1"
)
echo Done^^!
echo.

:: Chkdsking the Volumes and writing to log
for /F %%x in (!workdir!\chkdskA) do (
    echo Processing %%x
    (
        echo.
        echo ###################################### %%x ######################################
        echo.
        :: Run chkdsk and save output to a temporary file for each volume
        chkdsk %%x
    ) >> "!workdir!\chkdskATMP"
    
    :: Log error level for each volume
    echo %%x !errorLevel! >> "!workdir!\chkdskAvolumes"
    echo %%x !errorLevel! >> "!workdir!\resultSimple"
    set /a "currentvolume+=1"
    echo %%x Done^^! (!currentvolume!/!totalvolume!^)
)
echo.

:: Assemble final log
(
    type "!workdir!\chkdskAvolumes"
    type "!workdir!\chkdskATMP"
) > "!workdir!\chkdskA!timestamp!.txt"

:: Opening the log
echo Simplified results:
type "!workdir!\resultSimple"
echo Done^^!
echo.
echo Log: !workdir!\chkdskA!timestamp!.txt
echo.

:: Clears temporary files before concluding script
call :cleanup
echo.

:end
endlocal
pause
exit /b


:: Subsections
:get_timestamp
echo Getting timestamp...
:: Get the current date and time in a standardized format (YYYY.MM.DD.hh.mm.ss)
for /f "delims=" %%a in ('powershell -command "Get-Date -Format 'yyyy.MM.dd.HH.mm.ss'"') do set "timestamp=%%a"
goto :eof

:cleanup
echo Cleaning temporary files...
if exist "!workdir!\chkdskA" (del "!workdir!\chkdskA")
if exist "!workdir!\chkdskATMP" (del "!workdir!\chkdskATMP")
if exist "!workdir!\chkdskAvolumes" (del "!workdir!\chkdskAvolumes")
if exist "!workdir!\resultSimple" (del "!workdir!\resultSimple")
goto :eof