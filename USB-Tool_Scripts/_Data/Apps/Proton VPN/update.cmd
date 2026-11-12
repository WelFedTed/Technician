@echo off

title Updating Proton VPN

rem Updates this app with the shared helper _Data\Apps\_Update-App.ps1 (see that file for the options)
rem Run it on its own, or let Update-Tool.cmd run it for every app

rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0." ^
    -Name "Proton VPN" ^
    -GitHub "ProtonVPN/win-app" ^
    -Asset "^ProtonVPN_v[\d.]+_x64\.exe$" -Into "x64" ^
    -AssetArm "^ProtonVPN_v[\d.]+_arm64\.exe$" -IntoArm "ARM64" ^
    -Clean
set "result=%errorlevel%"

if /i not "%~1" == "/nopause" pause
exit /b %result%
