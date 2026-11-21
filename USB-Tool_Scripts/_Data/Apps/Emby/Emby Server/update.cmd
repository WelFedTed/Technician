@echo off

title Updating Emby Server

rem Updates this app with the shared helper _Data\Apps\_Update-App.ps1 (see that file for the options)
rem Run it on its own, or let Update-Tool.cmd run it for every app
rem Each kind of download has its own folder here: Installer (install.cmd), Portable (run.cmd), CLI (cli.cmd)

rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
set "result=0"
set "resultRank=0"

rem Installer (Emby Server, which keeps a PC's films, TV, music and photos in libraries for Emby apps to play.
rem From the "Download Emby Server" link on emby.media's Windows server page: a small online installer (a ClickOnce
rem setup) that downloads the latest server as it installs, so it needs internet. The setup's own exe always says
rem 18.0 (Microsoft's ClickOnce bootstrapper), so its ClickOnce manifest is saved next to it and the version is
rem read from that (the installer's version, not the server's). It's kept in x86, as it runs on any Windows.
rem No MajorGeeks backup: MajorGeeks has no page for Emby)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\..\_Update-App.ps1" -AppDir "%~dp0Installer" ^
    -Name "Emby Server (installer)" ^
    -Page "https://emby.media/windows-server.html" ^
    -Url "https://embydata.com/downloads/server/release14/setup.exe" -Into "x86" ^
    -Extra "https://embydata.com/downloads/server/release14/MediaBrowser.Server.Installer.application" ^
    -VersionFrom "x86\MediaBrowser.Server.Installer.application" ^
    -VersionMatch "name=.MediaBrowser\.Server\.Installer. version=.([\d.]+)" ^
    -Clean
call :result

rem Portable (the 7z files of the latest stable release on Emby's GitHub, MediaBrowser/Emby.Releases, which also
rem has beta releases marked as pre-releases; those are skipped. The server needs nothing installed: .NET comes
rem with it, in its system folder. It keeps its settings, libraries and metadata in a programdata folder next to
rem system (eg. Portable\x64\programdata), which is kept when updating. Emby only makes 64-bit and 32-bit Intel and
rem AMD builds; ARM64 Windows runs the x64 one)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\..\_Update-App.ps1" -AppDir "%~dp0Portable" ^
    -Name "Emby Server (portable)" ^
    -GitHub "MediaBrowser/Emby.Releases" ^
    -Asset "^embyserver-win-x64-[\d.]+\.7z$" -Into "x64" ^
    -Asset86 "^embyserver-win-x86-[\d.]+\.7z$" -Into86 "x86" ^
    -Extract -Clean -Keep "programdata"
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