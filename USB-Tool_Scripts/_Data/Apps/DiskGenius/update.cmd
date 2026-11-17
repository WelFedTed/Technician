@echo off

title Updating DiskGenius

rem Updates this app with the shared helper _Data\Apps\_Update-App.ps1 (see that file for the options)
rem Run it on its own, or let Update-Tool.cmd run it for every app
rem Each kind of download has its own folder here: Installer (install.cmd), Portable (run.cmd), CLI (cli.cmd)

rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
set "result=0"
set "resultRank=0"

rem Installer (the free edition: its Standard and Professional features need a licence key, entered in the same program)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0Installer" ^
    -Name "DiskGenius (installer)" ^
    -Page "https://www.diskgenius.com/download.php" ^
    -Link "/dyna_download/\?software=DGEngSetup(\d+)\.exe" -UrlFormat "https://download.diskgenius.com/DGEngSetup{0}.exe" -Into "x86" ^
    -Clean
call :result

rem Portable (the free edition)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0Portable" ^
    -Name "DiskGenius (portable)" ^
    -Page "https://www.diskgenius.com/download.php" ^
    -Link "/dyna_download/\?software=DGEng(\d+)_x64\.zip" -UrlFormat "https://download.diskgenius.com/DGEng{0}_x64.zip" -Into "x64" ^
    -UrlFormat86 "https://download.diskgenius.com/DGEng{0}_x86.zip" -Into86 "x86" ^
    -Extract -Flatten -Clean -VersionFrom "x64\DiskGenius.exe"
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
