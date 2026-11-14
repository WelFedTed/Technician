@echo off

title Updating Sublime Text

rem Updates this app with the shared helper _Data\Apps\_Update-App.ps1 (see that file for the options)
rem Run it on its own, or let Update-Tool.cmd run it for every app

rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0." ^
    -Name "Sublime Text" ^
    -Page "https://www.sublimetext.com/download" ^
    -Link "Build (\d{4})" ^
    -UrlFormat "https://download.sublimetext.com/sublime_text_build_{0}_x64.zip" ^
    -Extract -Into "x64" -Clean -DataFolder "Data"
set "result=%errorlevel%"

if /i not "%~1" == "/nopause" pause
exit /b %result%
