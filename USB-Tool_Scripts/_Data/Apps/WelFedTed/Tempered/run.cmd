@echo off

title Tempered

rem Opens Tempered (the screen protector fit finder) in Microsoft Edge's InPrivate mode: the site when it can be
rem reached, or else the copy on the USB (update.cmd keeps it in Portable\Any), served to Edge from this PC by
rem _Data\Apps\_Serve-Site.ps1, as it needs a web server to load its catalogue.
rem run.cmd /offline opens the copy on the USB even when the site can be reached.

set "site=https://welfedted.github.io/tempered/"
set "copy=%~dp0Portable\Any"

if /i not "%~1" == "/offline" (
	"%SystemRoot%\System32\curl.exe" -s -f -I -L --max-time 8 -o nul "%site%"
	if not errorlevel 1 (
		start msedge --inprivate %site%
		exit /b
	)
	echo Couldn't reach Tempered online.
)

if not exist "%copy%\index.html" (
	echo There's no copy of Tempered on the USB yet ^(Update-Tool.cmd downloads it^), so opening the site anyway...
	start msedge --inprivate %site%
	exit /b
)
echo Opening the copy on the USB...
rem (in a window of its own, minimised: closing it stops the copy's web server; it also stops by itself when unused)
start "Tempered (offline copy)" /min powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\..\_Serve-Site.ps1" -Folder "%copy%" -Title "Tempered" -InPrivate
exit /b
