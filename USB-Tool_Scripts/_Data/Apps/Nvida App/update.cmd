@echo off

title Updating NVIDIA App

rem Updates this app with the shared helper _Data\Apps\_Update-App.ps1 (see that file for the options)
rem Run it on its own, or let Update-Tool.cmd run it for every app

rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0." ^
    -Name "NVIDIA App" ^
    -Page "https://www.nvidia.com/en-us/software/nvidia-app/" ^
    -Link "https://us\.download\.nvidia\.com/nvapp/client/[\d.]+/x64/NVIDIA_app_v[\d.]+_x64\.exe" ^
    -LinkArm "https://us\.download\.nvidia\.com/nvapp/client/[\d.]+/arm64/NVIDIA_app_v[\d.]+_arm64\.exe" ^
    -Into "x64" -IntoArm "ARM64" -Clean
set "result=%errorlevel%"

if /i not "%~1" == "/nopause" pause
exit /b %result%
