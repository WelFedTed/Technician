@echo off

title Updating SysGauge

rem Updates this app with the shared helper _Data\Apps\_Update-App.ps1 (see that file for the options)
rem Run it on its own, or let Update-Tool.cmd run it for every app
rem Each kind of download has its own folder here: Installer (install.cmd), Portable (run.cmd), CLI (cli.cmd)

rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
set "result=0"
set "resultRank=0"

rem Installer (SysGauge, Flexense's free system and performance monitor: the 64-bit and 32-bit setups of the free
rem edition, from the versioned links on sysgauge.com's downloads page. The setups carry no version of their own,
rem so it's read from the link. Flexense doesn't offer a portable version)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0Installer" ^
    -Name "SysGauge" ^
    -Page "https://www.sysgauge.com/downloads.html" ^
    -Link "setups_x64/sysgauge_setup_v[\d.]+_x64\.exe" -Into "x64" ^
    -Link86 "setups/sysgauge_setup_v[\d.]+\.exe" -Into86 "x86" ^
    -Clean ^
    -MajorGeeks "sysgauge:64-Bit" -MajorGeeks86 "sysgauge:32-Bit"
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
