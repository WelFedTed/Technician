@echo off

rem Opens the COPS Manual in Microsoft Edge's InPrivate mode, using its run.cmd: the site when it can be reached,
rem or else the copy on the USB (COPS-Manual.cmd /offline opens the copy anyway)
rem It finds _Data next to itself, so the USB tool works from a drive's root (eg. Z:\COPS-Manual.cmd) or from any folder (eg. a copy in D:\Tools\USB-Tool)

set "app=%~dp0_Data\Apps\COPS Manual\run.cmd"

if exist "%app%" (
	call "%app%" %*
	exit /b
)
rem (the USB's scripts are older than the offline copy: just the site)
start msedge --inprivate https://welfedted.github.io/cops-manual/
exit /b
