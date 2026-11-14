@echo off

title Updating TeamViewer

rem Updates this app with the shared helper _Data\Apps\_Update-App.ps1 (see that file for the options)
rem Run it on its own, or let Update-Tool.cmd run it for every app
rem Each kind of download has its own folder here: Installer (install.cmd), Portable (run.cmd), CLI (cli.cmd)

rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
set "result=0"
set "resultRank=0"

rem Installer
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0Installer" ^
    -Name "TeamViewer (installer)" ^
    -Url "https://download.teamviewer.com/download/TeamViewer_Setup_x64.exe" -Into "x64" ^
    -Url86 "https://download.teamviewer.com/download/TeamViewer_Setup.exe" -Into86 "x86" ^
    -UrlArm "https://download.teamviewer.com/download/TeamViewer_Setup_arm64.exe" -IntoArm "ARM64" ^
    -Clean
call :result

rem Portable
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0Portable" ^
    -Name "TeamViewer Portable (and QuickSupport)" ^
    -Url "https://download.teamviewer.com/download/TeamViewerPortable.zip" -Into "x86_x64" ^
    -Extra "https://download.teamviewer.com/download/TeamViewerQS_x64.exe" ^
    -Extract -Clean -Keep "TeamViewer.ini" ^
    -VersionFrom "x86_x64\TeamViewer.exe"
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
