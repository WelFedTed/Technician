@echo off

title Updating AnyBurn Portable

rem Updates this app with the shared helper _Data\Apps\_Update-App.ps1 (see that file for the options)
rem Run it on its own, or let Update-Tool.cmd run it for every app

rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0." ^
    -Name "AnyBurn Portable" ^
    -Url "https://www.anyburn.com/anyburn.zip" -Inner "AnyBurn(64-bit)" -Into "x64" ^
    -Url86 "https://www.anyburn.com/anyburn.zip" -Inner86 "AnyBurn(32-bit)" -Into86 "x86" ^
    -Extract -Clean
set "result=%errorlevel%"

if /i not "%~1" == "/nopause" pause
exit /b %result%
