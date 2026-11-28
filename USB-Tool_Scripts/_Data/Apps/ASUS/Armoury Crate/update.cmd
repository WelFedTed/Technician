@echo off

title Updating Armoury Crate

rem Updates this app with the shared helper _Data\Apps\_Update-App.ps1 (see that file for the options)
rem Run it on its own, or let Update-Tool.cmd run it for every app
rem Each kind of download has its own folder here: Installer (install.cmd), Portable (run.cmd), CLI (cli.cmd)

rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
set "result=0"
set "resultRank=0"

rem Installer (ASUS's Armoury Crate install tool, as listed in winget: a small installer that downloads
rem Armoury Crate and the parts this PC needs, so it needs the internet. No MajorGeeks backup: it isn't
rem listed there)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\..\_Update-App.ps1" -AppDir "%~dp0Installer" ^
    -Name "Armoury Crate (installer)" ^
    -Page "https://www.asus.com/supportonly/armoury%%20crate/helpdesk_download/" ^
    -Winget "Asus.ArmouryCrate" -Into "Any" ^
    -Clean
call :result

rem Portable (ASUS's Armoury Crate Uninstall Tool, which run.cmd starts: it removes Armoury Crate and its
rem services and drivers completely, eg. before reinstalling it when it won't update or open)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\..\_Update-App.ps1" -AppDir "%~dp0Portable" ^
    -Name "Armoury Crate Uninstall Tool" ^
    -Page "https://www.asus.com/supportonly/armoury%%20crate/helpdesk_download/" ^
    -Url "https://dlcdnets.asus.com/pub/ASUS/mb/14Utilities/Armoury_Crate_Uninstall_Tool.zip" -Into "Any" ^
    -Extract -Flatten -Clean ^
    -MajorGeeks "armoury_crate_uninstall_tool"
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
