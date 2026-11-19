@echo off

title Updating Plezy

rem Updates this app with the shared helper _Data\Apps\_Update-App.ps1 (see that file for the options)
rem Run it on its own, or let Update-Tool.cmd run it for every app
rem Each kind of download has its own folder here: Installer (install.cmd), Portable (run.cmd), CLI (cli.cmd)

rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
set "result=0"
set "resultRank=0"

rem Installer (Plezy, by edde746 on GitHub: a client for Plex, Jellyfin and Emby media servers. One installer
rem for x64 and ARM64 Windows, which installs the right build itself; it's kept in x64, which install.cmd also
rem looks in on ARM64 Windows)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0Installer" ^
    -Name "Plezy (installer)" ^
    -GitHub "edde746/plezy" ^
    -Asset "^plezy-windows-installer\.exe$" -Into "x64" ^
    -Clean
call :result

rem Portable (the same release's 7z files. Portable here only means it doesn't update itself: its settings and
rem server sign-ins are still kept in the PC's user profile, not on the USB)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0Portable" ^
    -Name "Plezy (portable)" ^
    -GitHub "edde746/plezy" ^
    -Asset "^plezy-windows-x64-portable\.7z$" -Into "x64" ^
    -AssetArm "^plezy-windows-arm64-portable\.7z$" -IntoArm "ARM64" ^
    -Extract -Flatten -Clean
call :result

if /i not "%~1" == "/nopause" pause
exit /b %result%

rem keeps the worst result: failed (1), then needs a manual update (2), then Defender blocked files (3), then OK (0)
:result
set "code=%errorlevel%"
set "rank=3"
if "%code%" == "0" set "rank=0"
if "%code%" == "3" set "rank=1"
if "%code%" == "2" set "rank=2"
if %rank% GTR %resultRank% (
	set "resultRank=%rank%"
	set "result=%code%"
	if %rank% == 3 set "result=1"
)
exit /b 0