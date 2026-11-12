@echo off

title Updating Tweaking.com - Windows Repair

rem Updates this app with the shared helper _Data\Apps\_Update-App.ps1 (see that file for the options)
rem Run it on its own, or let Update-Tool.cmd run it for every app

rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0." ^
    -Name "Tweaking.com - Windows Repair" ^
    -Url "https://www.tweaking.com/files/setups/tweaking.com_windows_repair_aio.zip" ^
    -Extract -Flatten -Into "x86_x64" -Clean
set "result=%errorlevel%"

if /i not "%~1" == "/nopause" pause
exit /b %result%
