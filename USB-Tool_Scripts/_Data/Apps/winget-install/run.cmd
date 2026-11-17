@echo off

title winget-install

rem Runs asheroto's winget-install.ps1 (installs or repairs winget; eg. run.cmd -Force)
rem As admin, in a new PowerShell window: with internet, its latest version straight from the web, as "irm https://asheroto.com/winget | iex" does;
rem without internet (or if Windows blocks that), the copy on the USB. Any arguments are passed to it.

set "script=%~dp0Portable\Any\winget-install.ps1"
if not exist "%script%" set "script=%~dp0Portable\x86\winget-install.ps1"
if not exist "%script%" set "script=%~dp0Portable\winget-install.ps1"

rem _Run-Web.ps1 is in _Data\Apps, one or two folders up
set "webRunner="
for %%D in ("%~dp0.." "%~dp0..\..") do if not defined webRunner if exist "%%~fD\_Run-Web.ps1" set "webRunner=%%~fD\_Run-Web.ps1"
if not defined webRunner (
	echo Couldn't find _Run-Web.ps1 in _Data\Apps.
	pause
	exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%webRunner%" -Name "winget-install" -Web "https://asheroto.com/winget" -Local "%script%" -Admin -Arguments "%*"
if errorlevel 1 pause
exit /b
