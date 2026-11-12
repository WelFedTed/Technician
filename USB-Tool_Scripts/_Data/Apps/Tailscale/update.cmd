@echo off

title Updating Tailscale

rem Updates this app with the shared helper _Data\Apps\_Update-App.ps1 (see that file for the options)
rem Run it on its own, or let Update-Tool.cmd run it for every app

rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0." ^
    -Name "Tailscale" ^
    -Page "https://pkgs.tailscale.com/stable/" ^
    -Link "tailscale-setup-[\d.]+-amd64\.msi" ^
    -Link86 "tailscale-setup-[\d.]+-x86\.msi" ^
    -LinkArm "tailscale-setup-[\d.]+-arm64\.msi" ^
    -Into "x64" -Into86 "x86" -IntoArm "ARM64" -Clean
set "result=%errorlevel%"

if /i not "%~1" == "/nopause" pause
exit /b %result%
