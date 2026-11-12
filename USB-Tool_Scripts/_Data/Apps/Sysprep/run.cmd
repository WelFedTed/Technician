@echo off

title Sysprep

rem Sysprep is built into Windows, so this starts the copy on this PC (as admin)
rem Answer files or notes for Sysprep can be kept in this folder

set "sysprep=%WINDIR%\System32\Sysprep\sysprep.exe"
if not exist "%sysprep%" (
	echo Couldn't find "%sysprep%" on this PC.
	pause
	exit /b 1
)
powershell -NoProfile -Command "Start-Process -FilePath '%sysprep%' -WorkingDirectory '%WINDIR%\System32\Sysprep' -Verb RunAs"
exit /b
