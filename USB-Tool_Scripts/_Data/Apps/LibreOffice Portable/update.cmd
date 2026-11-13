@echo off

title Updating LibreOffice Portable

rem Updates this app with the shared helper _Data\Apps\_Update-App.ps1 (see that file for the options)
rem Run it on its own, or let Update-Tool.cmd run it for every app

rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0." ^
    -Name "LibreOffice Portable" ^
    -Page "https://portableapps.com/apps/office/libreoffice_portable" ^
    -Link "LibreOfficePortable_([\d.]+)_MultilingualStandard\.paf\.exe" ^
    -UrlFormat "https://download.documentfoundation.org/libreoffice/portable/{0}/LibreOfficePortable_{0}_MultilingualStandard.paf.exe" -Into "x64" ^
    -Page86 "https://portableapps.com/apps/office/libreoffice-portable-still" ^
    -Link86 "LibreOfficePortablePrevious_([\d.]+)_MultilingualStandard\.paf\.exe" ^
    -UrlFormat86 "https://download.documentfoundation.org/libreoffice/portable/{0}/LibreOfficePortablePrevious_{0}_MultilingualStandard.paf.exe" -Into86 "x86" ^
    -Clean ^
    -Paf
set "result=%errorlevel%"

if /i not "%~1" == "/nopause" pause
exit /b %result%
