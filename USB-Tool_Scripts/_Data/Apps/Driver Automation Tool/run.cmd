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

rem check if already elevated, and if not, start again as administrator
NET FILE 1>NUL 2>NUL
rem (Windows PowerShell won't take an empty -ArgumentList, so it's only given when there are arguments)
if not "%errorlevel%" == "0" (
	if "%~1" == "" (
		powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
	) else (
		powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -ArgumentList '%*' -Verb RunAs"
	)
	exit /b
)

echo Starting the Driver Automation Tool...
start "Driver Automation Tool" powershell -NoProfile -ExecutionPolicy Bypass -File "%script%" -NoShortcut %*
exit /b