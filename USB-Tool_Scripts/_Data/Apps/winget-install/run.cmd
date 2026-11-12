@echo off

title winget-install

rem Runs asheroto's winget-install.ps1 (installs or repairs winget) as admin in a new PowerShell window
rem Any arguments are passed to the script, eg. run.cmd -Force

set "script=%~dp0x86\winget-install.ps1"
if not exist "%script%" set "script=%~dp0winget-install.ps1"
if not exist "%script%" (
	echo Couldn't find winget-install.ps1 in "%~dp0"
	echo Run Update-Tool.cmd to download it.
	pause
	exit /b 1
)
powershell -NoProfile -Command "Start-Process powershell -Verb RunAs -ArgumentList '-NoProfile -ExecutionPolicy Bypass -NoExit -File \"%script%\" %*'"
exit /b
