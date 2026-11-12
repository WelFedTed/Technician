@echo off

title Updating Microsoft Visual C++ Redistributable (latest)

rem Updates this app with the shared helper _Data\Apps\_Update-App.ps1 (see that file for the options)
rem Run it on its own, or let Update-Tool.cmd run it for every app

rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0." ^
    -Name "Microsoft Visual C++ Redistributable (latest)" ^
    -Url "https://aka.ms/vs/17/release/vc_redist.x64.exe" -SaveAs "VC_redist.x64.exe" -Into "x64" ^
    -Url86 "https://aka.ms/vs/17/release/vc_redist.x86.exe" -SaveAs86 "VC_redist.x86.exe" -Into86 "x86" ^
    -UrlArm "https://aka.ms/vs/17/release/vc_redist.arm64.exe" -SaveAsArm "VC_redist.arm64.exe" -IntoArm "ARM64"
set "result=%errorlevel%"

if /i not "%~1" == "/nopause" pause
exit /b %result%
