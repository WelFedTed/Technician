@echo off

title Updating Custom Resolution Utility (CRU)

rem Updates this app with the shared helper _Data\Apps\_Update-App.ps1 (see that file for the options)
rem Run it on its own, or let Update-Tool.cmd run it for every app
rem Each kind of download has its own folder here: Installer (install.cmd), Portable (run.cmd), CLI (cli.cmd)

rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
set "result=0"
set "resultRank=0"

rem Portable (CRU.exe, 32-bit, runs everywhere, with restart.exe / restart64.exe to restart the graphics driver and
rem reset-all.exe to undo every change. Each asks for admin rights itself, as they change the monitor settings in
rem the registry)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0Portable" ^
    -Name "Custom Resolution Utility (CRU)" ^
    -Page "https://www.monitortests.com/forum/Thread-Custom-Resolution-Utility-CRU" ^
    -Link "https://www\.monitortests\.com/download/cru/cru-([\d.]+)\.zip" ^
    -Extract -Into "x86" -Clean ^
    -MajorGeeks "custom_resolution_utility"
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
