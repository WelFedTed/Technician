@echo off

title Driver Automation Tool

rem Starts the Driver Automation Tool (a PowerShell app, so not from _Run-Template.cmd, which starts .exe files)
rem as administrator, which it needs. -NoShortcut: it doesn't put a desktop shortcut to the USB on this PC.
rem Arguments given to this script are passed on (eg. "run.cmd -Theme Light").
rem It still notes where it was started from in the registry (HKLM\SOFTWARE\DriverAutomationTool), as it always does.

set "script=%~dp0Portable\Any\Start-DriverAutomationTool.ps1"
if not exist "%script%" (
	echo Couldn't find "%script%"
	echo Run Update-Tool.cmd to download it, or check the app's folder.
	pause
	exit /b 1
)

rem check if already elevated, and if not, start again as administrator (as _Run-Template.cmd does: fltmc works
rem without the Server service, and the path and arguments reach PowerShell in variables, so ' & ( in them are kept)
fltmc >nul 2>&1
if not errorlevel 1 goto elevated
set "selfPath=%~f0"
set "selfArgs=%*"
powershell -NoProfile -Command "$q = [char]34; $line = '/d /c ' + $q + $q + $env:selfPath + $q + ' ' + $env:selfArgs + $q; try { Start-Process -FilePath ($env:SystemRoot + '\System32\cmd.exe') -ArgumentList $line -Verb RunAs -ErrorAction Stop } catch { exit 1 }"
if errorlevel 1 (
	echo Couldn't start it as administrator ^(was the UAC prompt declined?^)
	pause
	exit /b 1
)
exit /b
:elevated

echo Starting the Driver Automation Tool...
start "Driver Automation Tool" powershell -NoProfile -ExecutionPolicy Bypass -File "%script%" -NoShortcut %*
exit /b