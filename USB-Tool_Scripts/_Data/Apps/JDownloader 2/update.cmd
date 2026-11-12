@echo off

title Updating JDownloader 2

rem Updates this app with the shared helper _Data\Apps\_Update-App.ps1 (see that file for the options)
rem Run it on its own, or let Update-Tool.cmd run it for every app

rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0." ^
    -Name "JDownloader 2" ^
    -Manual ^
    -Page "https://jdownloader.org/jdownloader2" ^
    -Note "JDownloader is downloaded through file-hosting mirrors, so get it by hand."
set "result=%errorlevel%"

if /i not "%~1" == "/nopause" pause
exit /b %result%
