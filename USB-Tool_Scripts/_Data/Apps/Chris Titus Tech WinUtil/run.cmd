@echo off

title WinUtil

rem Runs Chris Titus Tech's Windows Utility (WinUtil)
rem As admin, in a new PowerShell window: with internet, its latest version straight from the web, as "irm https://christitus.com/win | iex" does;
rem without internet (or if Windows blocks that), the copy on the USB. Any arguments are passed to it.

set "script=%~dp0Portable\Any\winutil.ps1"
if not exist "%script%" set "script=%~dp0Portable\x86\winutil.ps1"
if not exist "%script%" set "script=%~dp0Portable\winutil.ps1"

rem _Run-Web.ps1 is in _Data\Apps, one or two folders up
set "webRunner="
for %%D in ("%~dp0.." "%~dp0..\..") do if not defined webRunner if exist "%%~fD\_Run-Web.ps1" set "webRunner=%%~fD\_Run-Web.ps1"
if not defined webRunner (
	echo Couldn't find _Run-Web.ps1 in _Data\Apps.
	pause
	exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%webRunner%" -Name "WinUtil" -Web "https://christitus.com/win" -Local "%script%" -Admin -Arguments "%*"
if errorlevel 1 pause
exit /b
