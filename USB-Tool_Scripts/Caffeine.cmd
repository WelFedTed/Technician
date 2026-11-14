@echo off

rem Keeps the PC awake with Caffeine++, using its cli.cmd (a command prompt that starts it straight away)
rem Options are passed on, eg. Caffeine.cmd -t 3600 (an hour), -i (hide the window); close the window to stop it
rem To add a launcher: copy this file, rename it (eg. MyApp.cmd) and set the app's folder below, with the
rem app's install.cmd (installer), run.cmd (portable app) or cli.cmd (command prompt for its command-line tools)
rem It finds _Data next to itself, so the USB tool works from a drive's root (eg. Z:\MyApp.cmd) or from any folder (eg. a copy in D:\Tools\USB-Tool)

set "app=%~dp0_Data\Apps\Caffeine++\cli.cmd"

if not exist "%app%" (
	echo Couldn't find "%app%"
	echo Run Update-Tool.cmd to get the latest scripts.
	pause
	exit /b 1
)
call "%app%" %*
exit /b
