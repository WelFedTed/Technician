@echo off

title Updating Rclone

rem Updates this app with the shared helper _Data\Apps\_Update-App.ps1 (see that file for the options)
rem Run it on its own, or let Update-Tool.cmd run it for every app

rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0." ^
    -Name "Rclone" ^
    -GitHub "rclone/rclone" ^
    -Asset "^rclone-v[\d.]+-windows-amd64\.zip$" -Into "x64" ^
    -Asset86 "^rclone-v[\d.]+-windows-386\.zip$" -Into86 "x86" ^
    -AssetArm "^rclone-v[\d.]+-windows-arm64\.zip$" -IntoArm "ARM64" ^
    -Extract -Flatten -Clean
set "result=%errorlevel%"

if /i not "%~1" == "/nopause" pause
exit /b %result%
