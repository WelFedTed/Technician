@echo off

title Updating NirSoft PasswordFox

rem Updates this app with the shared helper _Data\Apps\_Update-App.ps1 (see that file for the options)
rem Run it on its own, or let Update-Tool.cmd run it for every app

rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0." ^
    -Name "NirSoft PasswordFox" ^
    -Url "https://www.nirsoft.net/toolsdownload/passwordfox-x64.zip" -Into "x64" ^
    -Url86 "https://www.nirsoft.net/toolsdownload/passwordfox.zip" -Into86 "x86" ^
    -Referer "https://www.nirsoft.net/utils/passwordfox.html" ^
    -Password "nspsfx403!" ^
    -Extract -Clean -Keep "*.cfg"
set "result=%errorlevel%"

if /i not "%~1" == "/nopause" pause
exit /b %result%
