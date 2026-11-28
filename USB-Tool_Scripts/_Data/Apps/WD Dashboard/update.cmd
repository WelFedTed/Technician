@echo off

title Updating WD Dashboard

rem Updates this app with the shared helper _Data\Apps\_Update-App.ps1 (see that file for the options)
rem Run it on its own, or let Update-Tool.cmd run it for every app
rem Each kind of download has its own folder here: Installer (install.cmd), Portable (run.cmd), CLI (cli.cmd)

rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
set "result=0"
set "resultRank=0"

rem Installer (SanDisk Dashboard, formerly WD Dashboard: health, firmware and settings for WD and SanDisk SSDs.
rem It's a small setup that downloads the app as it installs, so installing needs internet. The old
rem wddashboarddownloads.wdc.com address has an expired certificate since WD's SSDs moved to SanDisk.
rem No MajorGeeks backup: it isn't listed there)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0Installer" ^
    -Name "WD Dashboard (SanDisk Dashboard installer)" ^
    -Page "https://support-en.sandisk.com/app/products/product-detailweb/p/279" ^
    -Url "https://sddashboarddownloads.sandisk.com/wdDashboard/DashboardSetup.exe" ^
    -Into "x86" -Clean
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
