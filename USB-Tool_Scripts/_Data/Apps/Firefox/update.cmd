@echo off

title Updating Firefox

rem Updates this app with the shared helper _Data\Apps\_Update-App.ps1 (see that file for the options)
rem Run it on its own, or let Update-Tool.cmd run it for every app
rem Each kind of download has its own folder here: Installer (install.cmd), Portable (run.cmd), CLI (cli.cmd)

rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
set "result=0"
set "resultRank=0"

rem Installer
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0Installer" -MoveFrom "%~dp0..\Mozilla Firefox" ^
    -Name "Firefox (installer)" ^
    -Url "https://download.mozilla.org/?product=firefox-latest-ssl&os=win64&lang=en-US" ^
    -SaveAs "Firefox Setup.exe" -Into "x64" ^
    -Url86 "https://download.mozilla.org/?product=firefox-latest-ssl&os=win&lang=en-US" ^
    -SaveAs86 "Firefox Setup.exe" -Into86 "x86" ^
    -UrlArm "https://download.mozilla.org/?product=firefox-latest-ssl&os=win64-aarch64&lang=en-US" ^
    -SaveAsArm "Firefox Setup.exe" -IntoArm "ARM64" ^
    -VersionFromUrl
call :result

rem Portable
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0Portable" -MoveFrom "%~dp0..\Firefox Portable" ^
    -Name "Firefox Portable" ^
    -Page "https://portableapps.com/apps/internet/firefox_portable" ^
    -Link "f=(FirefoxPortable_[\d.]+_English\.paf\.exe)" ^
    -UrlFormat "https://download2.portableapps.com/portableapps/FirefoxPortable/{0}" -Into "x86_x64" ^
    -Clean ^
    -Paf
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
