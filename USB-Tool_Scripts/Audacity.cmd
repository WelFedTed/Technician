@echo off

rem Starts Audacity Portable using its run.cmd, which picks the right build (x64 / x86 / ARM64) for this PC
rem To add a launcher: copy this file, rename it (eg. MyApp.cmd) and set the app's folder below, with the
rem app's install.cmd (installer), run.cmd (portable app) or cli.cmd (command prompt for its command-line tools)
rem Run it from the root of the USB tool (eg. Z:\MyApp.cmd); it works whatever the drive letter is

set "app=%~d0\_Data\Apps\Audacity\run.cmd"

if not exist "%app%" (
	echo Couldn't find "%app%"
	echo Run Update-Tool.cmd to get the latest scripts.
	pause
	exit /b 1
)
call "%app%" %*
exit /b
