@echo off

title Updating Plex Media Server

rem Updates this app with the shared helper _Data\Apps\_Update-App.ps1 (see that file for the options)
rem Run it on its own, or let Update-Tool.cmd run it for every app
rem Each kind of download has its own folder here: Installer (install.cmd), Portable (run.cmd), CLI (cli.cmd)

rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
set "result=0"
set "resultRank=0"

rem Installer (Plex Media Server, which keeps a PC's films, TV, music and photos in libraries for Plex apps to
rem play. Its link is read from the list of downloads Plex's own download page uses, plex.tv/api/downloads/5.json.
rem Plex only makes it for 64-bit Intel and AMD Windows now, so it's kept in x64. No MajorGeeks backup: MajorGeeks'
rem page for it is gone)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\..\_Update-App.ps1" -AppDir "%~dp0Installer" ^
    -Name "Plex Media Server" ^
    -Page "https://plex.tv/api/downloads/5.json" ^
    -Link "https://downloads\.plex\.tv/plex-media-server-new/[\w.-]+/windows/PlexMediaServer-[\w.-]+-x86_64\.exe" -Into "x64" ^
    -Clean
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