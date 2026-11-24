@echo off

title Update Office Apps

rem Runs _Data\Scripts\update-office-apps.cmd from the USB tool this launcher is in (in a window of its own)
if not exist "%~dp0_Data\Scripts\update-office-apps.cmd" (
	echo Couldn't find "%~dp0_Data\Scripts\update-office-apps.cmd"
	echo Run Update-Tool.cmd to get the latest scripts.
	pause
	exit /b 1
)
rem (in a new window, by its full path: start "" "<path>" can't start a script whose path has a & in it, and
rem  start /d "<folder>" <name> would run a script of the same name on the PATH first)
start "" "%ComSpec%" /d /c call "%~dp0_Data\Scripts\update-office-apps.cmd"
exit /b
