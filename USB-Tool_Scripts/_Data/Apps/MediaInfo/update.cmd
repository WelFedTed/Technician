@echo off

title Updating MediaInfo

rem Updates this app with the shared helper _Data\Apps\_Update-App.ps1 (see that file for the options)
rem Run it on its own, or let Update-Tool.cmd run it for every app
rem Each kind of download has its own folder here: Installer (install.cmd), Portable (run.cmd), CLI (cli.cmd)

rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
set "result=0"
set "resultRank=0"

rem Installer
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0Installer" ^
    -Name "MediaInfo (installer)" ^
    -Page "https://mediaarea.net/en/MediaInfo/Download/Windows" ^
    -Link "//mediaarea\.net/download/binary/mediainfo-gui/[\d.]+/MediaInfo_GUI_[\d.]+_Windows_x64\.exe" -Into "x64" ^
    -Link86 "//mediaarea\.net/download/binary/mediainfo-gui/[\d.]+/MediaInfo_GUI_[\d.]+_Windows_i386\.exe" -Into86 "x86" ^
    -LinkArm "//mediaarea\.net/download/binary/mediainfo-gui/[\d.]+/MediaInfo_GUI_[\d.]+_Windows_ARM64\.exe" -IntoArm "ARM64" ^
    -Clean
call :result

rem Portable
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0Portable" -MoveFrom "%~dp0." ^
    -Name "MediaInfo" ^
    -Page "https://mediaarea.net/en/MediaInfo/Download/Windows" ^
    -Link "//mediaarea\.net/download/binary/mediainfo-gui/[\d.]+/MediaInfo_GUI_[\d.]+_Windows_x64_WithoutInstaller\.7z" ^
    -Link86 "//mediaarea\.net/download/binary/mediainfo-gui/[\d.]+/MediaInfo_GUI_[\d.]+_Windows_i386_WithoutInstaller\.7z" ^
    -LinkArm "//mediaarea\.net/download/binary/mediainfo-gui/[\d.]+/MediaInfo_GUI_[\d.]+_Windows_ARM64_WithoutInstaller\.7z" ^
    -Extract -Into "x64" -Into86 "x86" -IntoArm "ARM64" -Clean
call :result

rem CLI
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0CLI" ^
    -Name "MediaInfo command line" ^
    -Page "https://mediaarea.net/en/MediaInfo/Download/Windows" ^
    -Link "//mediaarea\.net/download/binary/mediainfo/[\d.]+/MediaInfo_CLI_[\d.]+_Windows_x64\.zip" -Into "x64" ^
    -Link86 "//mediaarea\.net/download/binary/mediainfo/[\d.]+/MediaInfo_CLI_[\d.]+_Windows_i386\.zip" -Into86 "x86" ^
    -LinkArm "//mediaarea\.net/download/binary/mediainfo/[\d.]+/MediaInfo_CLI_[\d.]+_Windows_ARM64\.zip" -IntoArm "ARM64" ^
    -Extract -Clean
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
