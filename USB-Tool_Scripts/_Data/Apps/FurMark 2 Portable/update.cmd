@echo off

title Updating FurMark 2

rem Updates this app with the shared helper _Data\Apps\_Update-App.ps1 (see that file for the options)
rem Run it on its own, or let Update-Tool.cmd run it for every app

rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0." ^
    -Name "FurMark 2" ^
    -Manual ^
    -Page "https://www.geeks3d.com/furmark/downloads/" ^
    -Note "Geeks3D has no fixed download link. Get the Windows 64-bit zip and put it in the x64 folder."
set "result=%errorlevel%"

if /i not "%~1" == "/nopause" pause
exit /b %result%
