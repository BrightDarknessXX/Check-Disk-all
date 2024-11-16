@echo off
echo Check disk all [v1.0]
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
set "cleanup=0"
set "totalvolume=0"
set "currentvolume=0"

:: Cleanup temporary files
:cleanup
echo Cleaning temporary files...
if exist "%tmp%\chkdskA" (del "%tmp%\chkdskA")
if exist "%tmp%\chkdskATMP" (del "%tmp%\chkdskATMP")
if exist "%tmp%\chkdskAvolumes" (del "%tmp%\chkdskAvolumes")
if !cleanup! equ 1 (goto :eof) else (set /a "cleanup+=1")

:: Getting Volumes to chkdsk on and writing to log
echo Volumes to check: >> "%tmp%\chkdskAvolumes"
echo Getting volumes...
wmic logicaldisk get deviceid | find ":" > "%tmp%\chkdskA"
for /F %%x in (%tmp%\chkdskA) do (
    set /a "totalvolume+=1"
)
echo Done^^!
echo.

:: Chkdsking the Volumes and writing to log
for /F %%x in (%tmp%\chkdskA) do (
    echo Processing %%x
    echo. >> "%tmp%\chkdskATMP"
    echo ###################################### %%x ###################################### >> "%tmp%\chkdskATMP"
    echo. >> "%tmp%\chkdskATMP"
    
    :: Run chkdsk and save output to a temporary file for each volume
    chkdsk %%x >> "%tmp%\chkdskATMP"

    :: Log problem status for each volume
    echo %%x !errorlevel! >> "%tmp%\chkdskAvolumes"
    set /a "currentvolume+=1"
    echo %%x Done^^! (!currentvolume!/!totalvolume!^)
)
echo.

:: Assemble final log
(
    type "%tmp%\chkdskAvolumes"
    type "%tmp%\chkdskATMP"
) > "%tmp%\chkdskA!timestamp!.txt"

:: Clears temporary files before concluding script
call :cleanup

:: Opening the log
echo Opening logfile...
start notepad "%tmp%\chkdskA!timestamp!.txt"
echo Done^^!


endlocal
timeout /t 5
exit /b


:: Subsections
:get_timestamp
echo Getting timestamp...
:: Get the current date and time in a standardized format (YYYY.MM.DD.hh.mm.ss)
for /f "delims=" %%a in ('powershell -command "Get-Date -Format 'yyyy.MM.dd.HH.mm.ss'"') do set "timestamp=%%a"
goto :eof