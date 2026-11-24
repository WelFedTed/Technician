@echo off
setlocal

title Shut Down

rem Shuts this PC down now (any open apps are closed without saving)
shutdown -s -f -t 00
if errorlevel 1 (
	echo:
	echo Couldn't shut down this PC ^(shutdown's exit code: %errorlevel%^).
	pause
	exit /b 1
)
exit /b
