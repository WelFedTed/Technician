@echo off

rem Opens Tempered (the screen protector fit finder) in Microsoft Edge's InPrivate mode, using its run.cmd: the site
rem when it can be reached, or else the copy on the USB (Tempered.cmd /offline opens the copy anyway)
rem It finds _Data next to itself, so the USB tool works from a drive's root (eg. Z:\Tempered.cmd) or from any folder (eg. a copy in D:\Tools\USB-Tool)

set "app=%~dp0_Data\Apps\WelFedTed\Tempered\run.cmd"

if exist "%app%" (
	call "%app%" %*
	exit /b
)
rem (the USB's scripts are older than the offline copy: just the site)
start msedge --inprivate https://welfedted.github.io/tempered/
exit /b
