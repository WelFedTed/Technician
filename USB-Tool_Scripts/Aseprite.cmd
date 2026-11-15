@echo off

rem Starts Aseprite using its run.cmd, which picks the right build (x64 / x86 / ARM64) for this PC
rem (Aseprite has to be built first: run _Data\Apps\Aseprite\build.cmd on a PC with Visual Studio 2022's C++ tools)
rem To add a launcher: copy this file, rename it (eg. MyApp.cmd) and set the app's folder below, with the
rem app's install.cmd (installer), run.cmd (portable app) or cli.cmd (command prompt for its command-line tools)
rem It finds _Data next to itself, so the USB tool works from a drive's root (eg. Z:\MyApp.cmd) or from any folder (eg. a copy in D:\Tools\USB-Tool)

set "app=%~dp0_Data\Apps\Aseprite\run.cmd"

if not exist "%app%" (
	echo Couldn't find "%app%"
	echo Run Update-Tool.cmd to get the latest scripts.
	pause
	exit /b 1
)
rem Aseprite isn't downloaded by Update-Tool.cmd: it's built with build.cmd
if not exist "%~dp0_Data\Apps\Aseprite\Portable\x64\aseprite.exe" (
	echo Aseprite hasn't been built yet.
	echo Run _Data\Apps\Aseprite\build.cmd on a PC with Visual Studio 2022's C++ tools to build it.
	pause
	exit /b 1
)
call "%app%" %*
exit /b
