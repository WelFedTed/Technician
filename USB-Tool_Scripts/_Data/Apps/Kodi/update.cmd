@echo off

title Updating Kodi

rem Updates this app with the shared helper _Data\Apps\_Update-App.ps1 (see that file for the options)
rem Run it on its own, or let Update-Tool.cmd run it for every app
rem Each kind of download has its own folder here: Installer (install.cmd), Portable (run.cmd), CLI (cli.cmd)

rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
set "result=0"
set "resultRank=0"

rem Installer (Kodi, the open source media center: the latest stable release's full installers, about 75 MB each,
rem from Kodi's own download folders on mirrors.kodi.tv, which send each download to a nearby mirror. The links
rem are read from the folder listings, leaving out betas and release candidates (named eg. 22.0-Piers_rc2).
rem Kodi only has ARM64 builds of its 22.0 pre-releases so far, so ARM64 Windows gets the x64 one for now)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0Installer" ^
    -Name "Kodi" ^
    -Page "https://mirrors.kodi.tv/releases/windows/win64/" ^
    -Link "kodi-\d+(?:\.\d+)+-[a-z]+-x64\.exe" -Into "x64" ^
    -Page86 "https://mirrors.kodi.tv/releases/windows/win32/" ^
    -Link86 "kodi-\d+(?:\.\d+)+-[a-z]+-x86\.exe" -Into86 "x86" ^
    -Clean ^
    -MajorGeeks "xbmc:64-Bit" -MajorGeeks86 "xbmc:32-Bit"
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