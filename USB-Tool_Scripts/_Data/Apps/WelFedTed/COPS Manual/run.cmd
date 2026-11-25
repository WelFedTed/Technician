@echo off

title COPS Manual

rem Opens the COPS Manual in Microsoft Edge's InPrivate mode: the site when it can be reached, or else the copy
rem on the USB (update.cmd keeps it in Portable\Any), served to Edge from this PC by _Data\Apps\_Serve-Site.ps1,
rem as the manual needs a web server for its links, menu and search.
rem run.cmd /offline opens the copy on the USB even when the site can be reached.

set "site=https://welfedted.github.io/cops-manual/"
set "copy=%~dp0Portable\Any"

if /i not "%~1" == "/offline" (
	"%SystemRoot%\System32\curl.exe" -s -f -I -L --max-time 8 -o nul "%site%"
	if not errorlevel 1 (
		start msedge --inprivate %site%
		exit /b
	)
	echo Couldn't reach the COPS Manual online.
)

if not exist "%copy%\index.html" (
	echo There's no copy of the COPS Manual on the USB yet ^(Update-Tool.cmd downloads it^), so opening the site anyway...
	start msedge --inprivate %site%
	exit /b
)
echo Opening the copy on the USB...
rem (in a window of its own, minimised: closing it stops the copy's web server; it also stops by itself when unused)
start "COPS Manual (offline copy)" /min powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\..\_Serve-Site.ps1" -Folder "%copy%" -Title "COPS Manual" -InPrivate
exit /b
