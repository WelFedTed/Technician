@echo off
setlocal

title Win11Debloat

rem Runs Raphire's Win11Debloat
rem As admin, in a new PowerShell window: with internet, its latest version straight from the web, as "irm https://debloat.raphi.re/ | iex" does;
rem without internet (or if Windows blocks that), the copy on the USB. Any arguments are passed to it (eg. "-RunDefaults").

set "script=%~dp0Portable\Any\Win11Debloat.ps1"
if not exist "%script%" set "script=%~dp0Portable\x86\Win11Debloat.ps1"
if not exist "%script%" set "script=%~dp0Portable\Win11Debloat.ps1"

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
powershell -NoProfile -ExecutionPolicy Bypass -File "%webRunner%" -Name "Win11Debloat" -Web "https://debloat.raphi.re/" -Local "%script%" -Admin
if errorlevel 1 pause
exit /b