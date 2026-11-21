@echo off

title Updating Jellyfin Media Player

rem Updates this app with the shared helper _Data\Apps\_Update-App.ps1 (see that file for the options)
rem Run it on its own, or let Update-Tool.cmd run it for every app
rem Each kind of download has its own folder here: Installer (install.cmd), Portable (run.cmd), CLI (cli.cmd)

rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
set "result=0"
set "resultRank=0"

rem Installer (Jellyfin Media Player, the desktop app for watching what's on a Jellyfin server, which plays nearly
rem any video itself with mpv. From the latest release on GitHub, jellyfin/jellyfin-media-player (now also named
rem jellyfin/jellyfin-desktop): x64 and x86 setups. Its x64-legacy setup is left out: it's for CPUs from before
rem about 2013, or PCs the x64 one gives a 0xc0000142 error on. The setups ask for admin rights themselves.
rem No MajorGeeks backup: MajorGeeks has no page for it)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\..\_Update-App.ps1" -AppDir "%~dp0Installer" ^
    -Name "Jellyfin Media Player" ^
    -GitHub "jellyfin/jellyfin-media-player" ^
    -Asset "^JellyfinMediaPlayer-[\d.]+-windows-x64\.exe$" -Into "x64" ^
    -Asset86 "^JellyfinMediaPlayer-[\d.]+-windows-x86\.exe$" -Into86 "x86" ^
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