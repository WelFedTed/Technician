@echo off

title Updating TeamSpeak 3

rem Updates this app with the shared helper _Data\Apps\_Update-App.ps1 (see that file for the options)
rem Run it on its own, or let Update-Tool.cmd run it for every app
rem Each kind of download has its own folder here: Installer (install.cmd), Portable (run.cmd), CLI (cli.cmd)

rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
set "result=0"
set "resultRank=0"

rem Installer (the TeamSpeak 3 client, still the stable one; the page only links the 64-bit installer, so the 32-bit one's link is made from it)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\..\_Update-App.ps1" -AppDir "%~dp0Installer" ^
    -Name "TeamSpeak 3" ^
    -Page "https://www.teamspeak.com/en/downloads/" ^
    -Link "https://files\.teamspeak-services\.com/releases/client/(3\.[\d.]+)/TeamSpeak3-Client-win64-[\d.]+\.exe" ^
    -UrlFormat "https://files.teamspeak-services.com/releases/client/{0}/TeamSpeak3-Client-win64-{0}.exe" -Into "x64" ^
    -UrlFormat86 "https://files.teamspeak-services.com/releases/client/{0}/TeamSpeak3-Client-win32-{0}.exe" -Into86 "x86" ^
    -Clean
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
