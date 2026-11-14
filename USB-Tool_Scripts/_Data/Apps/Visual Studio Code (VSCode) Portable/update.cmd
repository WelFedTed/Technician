@echo off

title Updating Visual Studio Code (portable zip)

rem Updates this app with the shared helper _Data\Apps\_Update-App.ps1 (see that file for the options)
rem Run it on its own, or let Update-Tool.cmd run it for every app

rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0." ^
    -Name "Visual Studio Code (portable zip)" ^
    -Url "https://update.code.visualstudio.com/latest/win32-x64-archive/stable" -Into "x64" ^
    -UrlArm "https://update.code.visualstudio.com/latest/win32-arm64-archive/stable" -IntoArm "ARM64" ^
    -Extract -Clean -DataFolder "data" ^
    -VersionFromUrl
set "result=%errorlevel%"

if /i not "%~1" == "/nopause" pause
exit /b %result%
