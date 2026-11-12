@echo off

title Updating MediaInfo

rem Updates this app with the shared helper _Data\Apps\_Update-App.ps1 (see that file for the options)
rem Run it on its own, or let Update-Tool.cmd run it for every app

rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0." ^
    -Name "MediaInfo" ^
    -Page "https://mediaarea.net/en/MediaInfo/Download/Windows" ^
    -Link "//mediaarea\.net/download/binary/mediainfo-gui/[\d.]+/MediaInfo_GUI_[\d.]+_Windows_x64_WithoutInstaller\.7z" ^
    -Link86 "//mediaarea\.net/download/binary/mediainfo-gui/[\d.]+/MediaInfo_GUI_[\d.]+_Windows_i386_WithoutInstaller\.7z" ^
    -LinkArm "//mediaarea\.net/download/binary/mediainfo-gui/[\d.]+/MediaInfo_GUI_[\d.]+_Windows_ARM64_WithoutInstaller\.7z" ^
    -Extract -Into "x64" -Into86 "x86" -IntoArm "ARM64" -Clean
set "result=%errorlevel%"

if /i not "%~1" == "/nopause" pause
exit /b %result%
