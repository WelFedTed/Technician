@echo off
setlocal

title Eject USB Tool

rem Safely ejects the USB drive this script is on (eg. run from E:\Eject.cmd, it ejects E:)
rem Uses _Data\Scripts\eject-drive.ps1: it's copied to %TEMP% and run from there in its own window, because
rem Windows won't eject a drive while this window (or a script on the drive) is still using it

set "drive=%~d0"
set "script=%~d0\_Data\Scripts\eject-drive.ps1"
set "copy=%TEMP%\USB-Tool-eject-drive.ps1"

if not exist "%script%" (
	echo Couldn't find "%script%"
	echo Run Update-Tool.cmd to get the latest scripts.
	pause
	exit /b 1
)
copy /y "%script%" "%copy%" >nul
if errorlevel 1 (
	echo Couldn't copy the eject script to "%TEMP%".
	pause
	exit /b 1
)

rem leave the drive: the new window starts in %TEMP%, and this one finishes straight away
cd /d "%TEMP%"
rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
start "Eject %drive%" /d "%TEMP%" powershell -NoProfile -ExecutionPolicy Bypass -File "%copy%" -Drive %drive%
exit /b
