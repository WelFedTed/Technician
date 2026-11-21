@echo off

title Updating DefenderUI

rem Updates this app with the shared helper _Data\Apps\_Update-App.ps1 (see that file for the options)
rem Run it on its own, or let Update-Tool.cmd run it for every app
rem Each kind of download has its own folder here: Installer (install.cmd), Portable (run.cmd), CLI (cli.cmd)

rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
set "result=0"
set "resultRank=0"

rem Installer (DefenderUI Free, a front end for Microsoft Defender's settings, from its maker CyberLock's (formerly
rem VoodooShield's) download link, which always gives the latest release. defenderui.com still has a download
rem button, but its file is an older version (1.46, from 2025). It's a small 32-bit setup, kept in x86.
rem The setup's file version is always 1.00 and only its product version has the real one (eg. 2.15), hence
rem -ProductVersion.
rem DefenderUI has no portable version; Pro is the paid edition, so it's left out)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0Installer" ^
    -Name "DefenderUI" ^
    -Page "https://www.cyberlock.global/DefenderUI.aspx" ^
    -Url "https://www.cyberlock.global/downloads/InstallDefenderUI.exe" -Into "x86" ^
    -ProductVersion -Clean ^
    -MajorGeeks "defenderui:EXE Free"
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
