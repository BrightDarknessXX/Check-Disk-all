@echo off
echo Check disk all [v1.2]
echo _BrightDarkness_
echo.

:: Check for elevated privileges
net session >nul 2>&1
if %errorLevel% NEQ 0 (
    ECHO **************************************
    ECHO Invoking UAC for Privilege Escalation
    ECHO **************************************
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)
ENDLOCAL

:: Enable delayed expansion for dynamic variable updates in loop
setlocal enabledelayedexpansion

:: Initialize
call :get_timestamp
set "workdir=%tmp%"
set "cleanup=0"
set "totalvolume=0"
set "currentvolume=0"

:: Cleanup temporary files
:cleanup
echo Cleaning temporary files...
if exist "!workdir!\chkdskA" (del "!workdir!\chkdskA")
if exist "!workdir!\chkdskATMP" (del "!workdir!\chkdskATMP")
if exist "!workdir!\chkdskAvolumes" (del "!workdir!\chkdskAvolumes")
if !cleanup! equ 1 (goto :eof) else (set /a "cleanup+=1")

:: Getting Volumes to chkdsk on and writing to log
echo Volumes to check: >> "!workdir!\chkdskAvolumes"
echo Getting volumes...
wmic logicaldisk get deviceid | find ":" > "!workdir!\chkdskA"
for /F %%x in (!workdir!\chkdskA) do (
    set /a "totalvolume+=1"
)
echo Done^^!
echo.

:: Chkdsking the Volumes and writing to log
for /F %%x in (!workdir!\chkdskA) do (
    echo Processing %%x
    echo. >> "!workdir!\chkdskATMP"
    echo ###################################### %%x ###################################### >> "!workdir!\chkdskATMP"
    echo. >> "!workdir!\chkdskATMP"
    
    :: Run chkdsk and save output to a temporary file for each volume
    chkdsk %%x >> "!workdir!\chkdskATMP"

    :: Log problem status for each volume
    echo %%x !errorlevel! >> "!workdir!\chkdskAvolumes"
    set /a "currentvolume+=1"
    echo %%x Done^^! (!currentvolume!/!totalvolume!^)
)
echo.

:: Assemble final log
(
    type "!workdir!\chkdskAvolumes"
    type "!workdir!\chkdskATMP"
) > "!workdir!\chkdskA!timestamp!.txt"

:: Clears temporary files before concluding script
call :cleanup

:: Opening the log
echo Opening logfile...
start notepad "!workdir!\chkdskA!timestamp!.txt"
echo Done^^!

echo.
echo Log: !workdir!\chkdskA!timestamp!.txt
echo.

endlocal
pause
exit /b


:: Subsections
:get_timestamp
echo Getting timestamp...
:: Get the current date and time in a standardized format (YYYY.MM.DD.hh.mm.ss)
for /f "delims=" %%a in ('powershell -command "Get-Date -Format 'yyyy.MM.dd.HH.mm.ss'"') do set "timestamp=%%a"
goto :eof
