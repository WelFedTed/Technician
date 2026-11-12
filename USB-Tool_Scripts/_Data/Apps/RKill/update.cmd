@echo off

title Updating RKill

rem Updates this app with the shared helper _Data\Apps\_Update-App.ps1 (see that file for the options)
rem Run it on its own, or let Update-Tool.cmd run it for every app

rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0." ^
    -Name "RKill" ^
    -Url "https://download.bleepingcomputer.com/grinler/rkill.exe" ^
    -SaveAs "rkill.exe" -Into "x86" ^
    -Extra "https://download.bleepingcomputer.com/grinler/rkill.com,https://download.bleepingcomputer.com/grinler/rkill.scr,https://download.bleepingcomputer.com/grinler/eXplorer.exe,https://download.bleepingcomputer.com/grinler/iExplore.exe,https://download.bleepingcomputer.com/grinler/uSeRiNiT.exe,https://download.bleepingcomputer.com/grinler/WiNlOgOn.exe" ^
    -Clean
set "result=%errorlevel%"

if /i not "%~1" == "/nopause" pause
exit /b %result%
