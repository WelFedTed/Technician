@echo off

title Updating HD Tune Pro

rem Updates this app with the shared helper _Data\Apps\_Update-App.ps1 (see that file for the options)
rem Run it on its own, or let Update-Tool.cmd run it for every app

rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0." ^
    -Name "HD Tune Pro" ^
    -Manual ^
    -Page "https://www.hdtune.com/download.html" ^
    -Note "HD Tune Pro is paid software, so download it and re-enter the licence by hand."
set "result=%errorlevel%"

if /i not "%~1" == "/nopause" pause
exit /b %result%
