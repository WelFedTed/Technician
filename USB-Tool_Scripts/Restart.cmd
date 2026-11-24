@echo off
setlocal

title Restart

rem Restarts this PC now (any open apps are closed without saving)
shutdown -r -f -t 00
if errorlevel 1 (
	echo:
	echo Couldn't restart this PC ^(shutdown's exit code: %errorlevel%^).
	pause
	exit /b 1
)
exit /b
