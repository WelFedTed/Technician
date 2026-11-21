@echo off

title Updating Tweaking.com - Repair Windows Firewall

rem Updates this app with the shared helper _Data\Apps\_Update-App.ps1 (see that file for the options)
rem Run it on its own, or let Update-Tool.cmd run it for every app
rem Each kind of download has its own folder here: Installer (install.cmd), Portable (run.cmd), CLI (cli.cmd)

rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
set "result=0"
set "resultRank=0"

rem Portable (Tweaking.com's Repair Windows Firewall 2.8.8: resets a broken Windows Firewall. Tweaking.com no longer
rem updates it (its repairs are now part of Windows Repair, which its page links to instead), but the program is
rem still on its download server, under the name it always had there. The download is a self-extracting RAR that
rem unpacks the program to a temporary folder and runs it, so it's unpacked here instead: repair.exe, which asks
rem for admin rights itself)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\..\_Update-App.ps1" -AppDir "%~dp0Portable" ^
    -Name "Tweaking.com - Repair Windows Firewall" ^
    -Page "https://www.tweaking.com/features/repair-windows-firewall/" ^
    -Url "https://www.tweaking.com/files/setups/Tweaking.com-RepairWindowsFirewall.exe" -Into "x86" ^
    -Extract -Sfx -Flatten -Clean ^
    -VersionFrom "x86\repair.exe" ^
    -MajorGeeks "tweaking_com_repair_windows_firewall"
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