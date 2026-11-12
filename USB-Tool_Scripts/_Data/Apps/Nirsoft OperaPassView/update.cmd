@echo off

title Updating NirSoft OperaPassView

rem Updates this app with the shared helper _Data\Apps\_Update-App.ps1 (see that file for the options)
rem Run it on its own, or let Update-Tool.cmd run it for every app

rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0." ^
    -Name "NirSoft OperaPassView" ^
    -Url "https://www.nirsoft.net/toolsdownload/operapassview.zip" -Into "x86" ^
    -Referer "https://www.nirsoft.net/utils/opera_password_recovery.html" ^
    -Extract -Clean -Keep "*.cfg"
set "result=%errorlevel%"

if /i not "%~1" == "/nopause" pause
exit /b %result%
