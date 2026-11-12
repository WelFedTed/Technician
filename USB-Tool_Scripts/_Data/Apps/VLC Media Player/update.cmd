@echo off

title Updating VLC Media Player

rem Updates this app with the shared helper _Data\Apps\_Update-App.ps1 (see that file for the options)
rem Run it on its own, or let Update-Tool.cmd run it for every app

rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0." ^
    -Name "VLC Media Player" ^
    -Page "https://download.videolan.org/pub/videolan/vlc/last/win64/" ^
    -Link "vlc-([\d.]+)-win64\.zip" ^
    -UrlFormat "https://download.videolan.org/pub/videolan/vlc/last/win64/vlc-{0}-win64.zip" ^
    -UrlFormat86 "https://download.videolan.org/pub/videolan/vlc/last/win32/vlc-{0}-win32.zip" ^
    -UrlFormatArm "https://download.videolan.org/pub/videolan/vlc/last/winarm64/vlc-{0}-winarm64.zip" ^
    -Extract -Flatten -Into "x64" -Into86 "x86" -IntoArm "ARM64" ^
    -Clean -Keep "portable"
set "result=%errorlevel%"

if /i not "%~1" == "/nopause" pause
exit /b %result%
