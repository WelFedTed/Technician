@echo off

title Updating Fort Firewall

rem Updates this app with the shared helper _Data\Apps\_Update-App.ps1 (see that file for the options)
rem Run it on its own, or let Update-Tool.cmd run it for every app
rem Each kind of download has its own folder here: Installer (install.cmd), Portable (run.cmd), CLI (cli.cmd)

rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
set "result=0"
set "resultRank=0"

rem Installer (Fort Firewall, by tnodir on GitHub: an open-source firewall that controls which programs may use the
rem network, with its own filter driver. The x64 and ARM64 builds are for Windows 10 and 11; the x86 one also runs
rem on Windows 7 and 8. Not built from source here: Windows only loads its driver when it's signed)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0Installer" ^
    -Name "Fort Firewall (installer)" ^
    -GitHub "tnodir/fort" ^
    -Asset "^FortFirewall-[\d.]+-windows10-x86_64\.exe$" -Into "x64" ^
    -Asset86 "^FortFirewall-[\d.]+-windows-x86\.exe$" -Into86 "x86" ^
    -AssetArm "^FortFirewall-[\d.]+-windows10-arm64\.exe$" -IntoArm "ARM64" ^
    -Clean ^
    -MajorGeeks "fort_firewall:64-Bit Windows 10" -MajorGeeks86 "fort_firewall:32-Bit" -MajorGeeksArm "fort_firewall:ARM64"
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