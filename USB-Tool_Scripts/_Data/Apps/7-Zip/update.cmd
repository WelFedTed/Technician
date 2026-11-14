@echo off

title Updating 7-Zip

rem Updates this app with the shared helper _Data\Apps\_Update-App.ps1 (see that file for the options)
rem Run it on its own, or let Update-Tool.cmd run it for every app
rem Each kind of download has its own folder here: Installer (install.cmd), Portable (run.cmd), CLI (cli.cmd)

rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
set "result=0"
set "resultRank=0"

rem Installer
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0Installer" -MoveFrom "%~dp0." ^
    -Name "7-Zip (installer)" ^
    -GitHub "ip7z/7zip" ^
    -Asset "^7z\d+-x64\.exe$" -Into "x64" ^
    -Asset86 "^7z\d+\.exe$" -Into86 "x86" ^
    -AssetArm "^7z\d+-arm64\.exe$" -IntoArm "ARM64" ^
    -Clean
call :result

rem Portable
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0Portable" -MoveFrom "%~dp0..\7-Zip Portable" ^
    -Name "7-Zip Portable" ^
    -Page "https://portableapps.com/apps/utilities/7-zip_portable" ^
    -Link "f=(7-ZipPortable_[\d.]+\.paf\.exe)" ^
    -UrlFormat "https://download2.portableapps.com/portableapps/7-ZipPortable/{0}" -Into "x86_x64_ARM64" ^
    -Clean ^
    -Paf
call :result

rem CLI
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0CLI" -MoveFrom "%~dp0..\7-Zip CLI" ^
    -Name "7-Zip command line (7-Zip Extra + 7zr.exe)" ^
    -GitHub "ip7z/7zip" ^
    -Asset "^7z\d+-extra\.7z$" -Into "x86_x64_ARM64" ^
    -Extract -Clean ^
    -Extra "https://www.7-zip.org/a/7zr.exe"
call :result

if /i not "%~1" == "/nopause" pause
exit /b %result%

rem keeps the worst result: failed (1), then needs a manual update (2), then Defender blocked files (3), then OK (0)
:result
set "code=%errorlevel%"
set "rank=3"
if "%code%" == "0" set "rank=0"
if "%code%" == "3" set "rank=1"
if "%code%" == "2" set "rank=2"
if %rank% GTR %resultRank% (
	set "resultRank=%rank%"
	set "result=%code%"
	if %rank% == 3 set "result=1"
)
exit /b 0
