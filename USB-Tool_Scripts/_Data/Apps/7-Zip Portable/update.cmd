@echo off

title Updating 7-Zip Portable

rem Updates this app with the shared helper _Data\Apps\_Update-App.ps1 (see that file for the options)
rem Run it on its own, or let Update-Tool.cmd run it for every app

rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0." ^
    -Name "7-Zip Portable" ^
    -Page "https://portableapps.com/apps/utilities/7-zip_portable" ^
    -Link "f=(7-ZipPortable_[\d.]+\.paf\.exe)" ^
    -UrlFormat "https://download2.portableapps.com/portableapps/7-ZipPortable/{0}" -Into "x86_x64_ARM64" ^
    -Clean ^
    -Paf
set "result=%errorlevel%"

if /i not "%~1" == "/nopause" pause
exit /b %result%
