@echo off

title Updating ReNamer (portable)

rem Updates this app with the shared helper _Data\Apps\_Update-App.ps1 (see that file for the options)
rem Run it on its own, or let Update-Tool.cmd run it for every app

rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0." ^
    -Name "ReNamer (portable)" ^
    -Page "https://www.den4b.com/download/renamer/portable" ^
    -Link "portable\?key=([0-9a-f]+)" ^
    -UrlFormat "https://www.den4b.com/download/renamer/portable?key={0}" ^
    -Extract -Into "x86" -Clean -Keep "*.ini"
set "result=%errorlevel%"

if /i not "%~1" == "/nopause" pause
exit /b %result%
