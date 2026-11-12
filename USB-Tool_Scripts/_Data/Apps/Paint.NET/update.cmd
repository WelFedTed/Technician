@echo off

title Updating Paint.NET (portable)

rem Updates this app with the shared helper _Data\Apps\_Update-App.ps1 (see that file for the options)
rem Run it on its own, or let Update-Tool.cmd run it for every app

rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0." ^
    -Name "Paint.NET (portable)" ^
    -GitHub "paintdotnet/release" ^
    -Asset "^paint\.net\.[\d.]+\.portable\.x64\.zip$" -Into "x64" ^
    -AssetArm "^paint\.net\.[\d.]+\.portable\.arm64\.zip$" -IntoArm "ARM64" ^
    -Extract -Clean
set "result=%errorlevel%"

if /i not "%~1" == "/nopause" pause
exit /b %result%
