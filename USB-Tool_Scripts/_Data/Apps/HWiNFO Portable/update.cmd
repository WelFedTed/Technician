@echo off

title Updating HWiNFO Portable

rem Updates this app with the shared helper _Data\Apps\_Update-App.ps1 (see that file for the options)
rem Run it on its own, or let Update-Tool.cmd run it for every app

rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0." ^
    -Name "HWiNFO Portable" ^
    -Page "https://www.hwinfo.com/download/" ^
    -Link "https://www\.hwinfo\.com/files/hwi_\d+\.zip" ^
    -Extract -Into "x86_x64_ARM64" -Clean -Keep "*.INI"
set "result=%errorlevel%"

if /i not "%~1" == "/nopause" pause
exit /b %result%
