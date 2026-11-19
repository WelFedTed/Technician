@echo off

title Updating Driver Automation Tool

rem Updates this app with the shared helper _Data\Apps\_Update-App.ps1 (see that file for the options)
rem Run it on its own, or let Update-Tool.cmd run it for every app
rem Each kind of download has its own folder here: Installer (install.cmd), Portable (run.cmd), CLI (cli.cmd)

rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
set "result=0"
set "resultRank=0"

rem Portable (Maurice Daly's Driver Automation Tool: downloads and packages HP, Dell, Lenovo, Surface and Acer
rem driver and BIOS packs for ConfigMgr, Intune or a plain folder. A PowerShell app with no releases: it's published
rem as the repo itself, so this takes its "Driver Automation Tool" folder from the repo's zip; the rest of the repo
rem is the catalogs, which the tool reads online. The version is its module's)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0Portable" ^
    -Name "Driver Automation Tool" ^
    -Url "https://github.com/maurice-daly/DriverAutomationTool/archive/refs/heads/master.zip" ^
    -Extract -Inner "DriverAutomationTool-master\Driver Automation Tool" -Into "Any" ^
    -VersionFrom "Any\Modules\DriverAutomationToolCore\DriverAutomationToolCore.psd1" ^
    -VersionMatch "ModuleVersion\s*=\s*'([\d.]+)'" ^
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