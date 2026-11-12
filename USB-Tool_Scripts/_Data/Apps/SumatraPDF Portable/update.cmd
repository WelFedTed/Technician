@echo off

title Updating SumatraPDF Portable

rem Updates this app with the shared helper _Data\Apps\_Update-App.ps1 (see that file for the options)
rem Run it on its own, or let Update-Tool.cmd run it for every app

rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0." ^
    -Name "SumatraPDF Portable" ^
    -Page "https://portableapps.com/apps/office/sumatra_pdf_portable" ^
    -Link "f=(SumatraPDFPortable_[\d.]+\.paf\.exe)" ^
    -UrlFormat "https://download2.portableapps.com/portableapps/SumatraPDFPortable/{0}" -Into "x86" ^
    -Clean
set "result=%errorlevel%"

if /i not "%~1" == "/nopause" pause
exit /b %result%
