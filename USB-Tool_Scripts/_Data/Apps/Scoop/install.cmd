@echo off
setlocal

title Install Scoop

rem Runs Scoop's installer (it installs Scoop for this user, not as admin)
rem In this window: with internet, its latest version straight from the web, as "irm https://get.scoop.sh | iex" does;
rem without internet (or if Windows blocks that), the copy on the USB. Any arguments are passed to it.

set "script=%~dp0Installer\Any\install.ps1"
if not exist "%script%" set "script=%~dp0Installer\x86\install.ps1"
if not exist "%script%" set "script=%~dp0Installer\install.ps1"

rem _Run-Web.ps1 is in _Data\Apps, one or two folders up
set "webRunner="
for %%D in ("%~dp0.." "%~dp0..\..") do if not defined webRunner if exist "%%~fD\_Run-Web.ps1" set "webRunner=%%~fD\_Run-Web.ps1"
if not defined webRunner (
	echo Couldn't find _Run-Web.ps1 in _Data\Apps.
	pause
	exit /b 1
)
rem (the arguments go to _Run-Web.ps1 in a variable: in -Arguments "...", quotes in them would end its quotes)
set "USB_TOOL_WEB_ARGUMENTS=%*"
powershell -NoProfile -ExecutionPolicy Bypass -File "%webRunner%" -Name "Install Scoop" -Web "https://get.scoop.sh" -Local "%script%"
echo:
pause
exit /b
