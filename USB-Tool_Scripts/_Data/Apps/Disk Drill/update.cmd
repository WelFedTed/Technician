@echo off

title Updating Disk Drill

rem Updates this app with the shared helper _Data\Apps\_Update-App.ps1 (see that file for the options)
rem Run it on its own, or let Update-Tool.cmd run it for every app

rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0." ^
    -Name "Disk Drill" ^
    -Url "https://win.cleverfiles.com/disk-drill-win.exe" ^
    -SaveAs "disk-drill-win.exe" -Into "x64"
set "result=%errorlevel%"

if /i not "%~1" == "/nopause" pause
exit /b %result%
