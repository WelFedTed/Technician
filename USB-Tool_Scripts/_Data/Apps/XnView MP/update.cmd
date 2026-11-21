@echo off

title Updating XnView MP

rem Updates this app with the shared helper _Data\Apps\_Update-App.ps1 (see that file for the options)
rem Run it on its own, or let Update-Tool.cmd run it for every app
rem Each kind of download has its own folder here: Installer (install.cmd), Portable (run.cmd), CLI (cli.cmd)

rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
set "result=0"
set "resultRank=0"

rem Installer (XnView MP, XnSoft's free image viewer, organiser and converter, from its own download links, which
rem always give the latest release. The current version is 64-bit only (Windows 10/11); XnSoft still offers the
rem last 32-bit version, 1.5.5 from 2023, which is kept in x86 for 32-bit PCs. There's no ARM64 Windows build.
rem MajorGeeks' own copy is only of the 32-bit setup; its 64-bit and ZIP buttons send you to XnSoft's own links)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0Installer" ^
    -Name "XnView MP (installer)" ^
    -Page "https://www.xnview.com/en/xnview-mp/" ^
    -Url "https://download.xnview.com/XnViewMP-win-x64.exe" -Into "x64" ^
    -Url86 "https://download.xnview.com/versions/XnView_MP/XnView_MP-1.5.5-win.exe" -Into86 "x86" ^
    -Clean ^
    -MajorGeeks "xnviewmp:64-Bit" -MajorGeeks86 "xnviewmp"
call :result

rem Portable (the same versions' zip files, unpacked here. On its first run it asks where to keep its settings:
rem "Portable (application folder)" keeps them on the USB, in xnview.ini, XnView.db and Thumb.db next to
rem xnviewmp.exe, which an update keeps. No MajorGeeks backup for the 32-bit zip: MajorGeeks doesn't have it)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0Portable" ^
    -Name "XnView MP (portable)" ^
    -Page "https://www.xnview.com/en/xnview-mp/" ^
    -Url "https://download.xnview.com/XnViewMP-win-x64.zip" -Into "x64" ^
    -Url86 "https://download.xnview.com/versions/XnView_MP/XnView_MP-1.5.5-win.zip" -Into86 "x86" ^
    -Extract -Flatten -Clean -Keep "xnview.ini,XnView.db,Thumb.db" ^
    -VersionFrom "x64\xnviewmp.exe" ^
    -MajorGeeks "xnviewmp:ZIP"
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
