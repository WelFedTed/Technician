@echo off
setlocal

title Wise Care 365

rem Starts the portable Wise Care 365: its zip has a WiseCare365_<version>(x64) and a (x86) folder (in
rem Portable\x86_x64), so this picks the one for this PC (ARM64 Windows runs the x64 one)
set "build=x64"
if /i "%PROCESSOR_ARCHITECTURE%" == "x86" if not defined PROCESSOR_ARCHITEW6432 set "build=x86"
set "exe="
for /d %%D in ("%~dp0Portable\x86_x64\WiseCare365_*(%build%)") do if exist "%%~fD\WiseCare365.exe" set "exe=%%~fD\WiseCare365.exe"
if not defined exe (
	echo Couldn't find the portable Wise Care 365 ^(%build%^) in "%~dp0Portable\x86_x64". Run update.cmd first.
	pause
	exit /b 1
)
echo %build% Wise Care 365: "%exe%"
start "" "%exe%" %*
exit /b