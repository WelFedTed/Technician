@echo off

title Updating Inkscape Portable

rem Updates this app with the shared helper _Data\Apps\_Update-App.ps1 (see that file for the options)
rem Run it on its own, or let Update-Tool.cmd run it for every app

rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0." ^
    -Name "Inkscape Portable" ^
    -Page "https://portableapps.com/apps/graphics_pictures/inkscape_portable" ^
    -Link "f=(InkscapePortable_[\d.]+\.paf\.exe)" ^
    -UrlFormat "https://download2.portableapps.com/portableapps/InkscapePortable/{0}" -Into "x64" ^
    -Page86 "https://portableapps.com/apps/graphics_pictures/inkscape_portable" ^
    -Link86 "f=(InkscapePortableLegacy32bit_[\d.]+\.paf\.exe)" ^
    -UrlFormat86 "https://download2.portableapps.com/portableapps/InkscapePortableLegacy32bit/{0}" -Into86 "x86" ^
    -Clean ^
    -Paf
set "result=%errorlevel%"

if /i not "%~1" == "/nopause" pause
exit /b %result%
