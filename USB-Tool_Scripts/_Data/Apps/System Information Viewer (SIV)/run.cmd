@echo off
setlocal

title System Information Viewer (SIV)

rem Starts the portable SIV: its zip (in Portable\x86_x64) has a build for each kind of Windows, so this picks
rem SIV64X.exe on 64-bit Windows (ARM64 Windows runs it too, as there's no ARM64 build) and SIV32X.exe on 32-bit
rem Windows. SIV asks for admin rights itself, which it needs for full detail
set "exe=SIV64X.exe"
if /i "%PROCESSOR_ARCHITECTURE%" == "x86" if not defined PROCESSOR_ARCHITEW6432 set "exe=SIV32X.exe"
if not exist "%~dp0Portable\x86_x64\%exe%" (
	echo Couldn't find %exe% in "%~dp0Portable\x86_x64". Run update.cmd first.
	pause
	exit /b 1
)
echo Starting %exe%...
cd /d "%~dp0Portable\x86_x64"
start "" "%exe%" %*
exit /b