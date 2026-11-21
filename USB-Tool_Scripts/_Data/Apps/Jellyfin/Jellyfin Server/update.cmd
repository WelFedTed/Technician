@echo off

title Updating Jellyfin Server

rem Updates this app with the shared helper _Data\Apps\_Update-App.ps1 (see that file for the options)
rem Run it on its own, or let Update-Tool.cmd run it for every app
rem Each kind of download has its own folder here: Installer (install.cmd), Portable (run.cmd), CLI (cli.cmd)

rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
set "result=0"
set "resultRank=0"

rem Installer (Jellyfin Server, the free and open-source media server that keeps a PC's films, TV, music and photos
rem in libraries for Jellyfin apps and web browsers to play. Its link is read from the latest stable release's
rem page on Jellyfin's own download site, repo.jellyfin.org (the GitHub releases of jellyfin-server-windows have no
rem files). Jellyfin only makes the installer for 64-bit Intel and AMD Windows, so it's kept in x64. The MajorGeeks
rem backup is its EXE button, which links to the same file on repo.jellyfin.org)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\..\_Update-App.ps1" -AppDir "%~dp0Installer" ^
    -Name "Jellyfin Server (installer)" ^
    -Page "https://repo.jellyfin.org/?path=/server/windows/latest-stable/amd64" ^
    -Link "/files/server/windows/latest-stable/amd64/jellyfin_[\d.]+_windows-x64\.exe" -Into "x64" ^
    -Clean ^
    -MajorGeeks "jellyfin:EXE"
call :result

rem Portable (the same release's .zip files, for 64-bit Intel and AMD and for ARM64 Windows, which has no installer.
rem run.cmd starts jellyfin.exe, the server itself, in a console window; it's then set up and used in a web browser
rem at http://localhost:8096. Its settings, libraries and metadata are kept in the PC's user profile
rem (%LOCALAPPDATA%\jellyfin), not on the USB. The ARM64 build comes without the FFmpeg the x64 one has, so it needs
rem one set in its settings to play or scan video. No MajorGeeks backup: its Portable button gives Jellyfin's
rem cross-platform .zip, not the Windows build, so it needs .NET and FFmpeg installed)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\..\_Update-App.ps1" -AppDir "%~dp0Portable" ^
    -Name "Jellyfin Server (portable)" ^
    -Page "https://repo.jellyfin.org/?path=/server/windows/latest-stable/amd64" ^
    -Link "/files/server/windows/latest-stable/amd64/jellyfin_[\d.]+-amd64\.zip" -Into "x64" ^
    -PageArm "https://repo.jellyfin.org/?path=/server/windows/latest-stable/arm64" ^
    -LinkArm "/files/server/windows/latest-stable/arm64/jellyfin_[\d.]+-arm64\.zip" -IntoArm "ARM64" ^
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