@echo off

title Updating Vivaldi

rem Updates this app with the shared helper _Data\Apps\_Update-App.ps1 (see that file for the options)
rem Run it on its own, or let Update-Tool.cmd run it for every app
rem Each kind of download has its own folder here: Installer (install.cmd), Portable (run.cmd), CLI (cli.cmd)

rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
set "result=0"
set "resultRank=0"

rem Installer (Vivaldi, the browser: its full installers, from the links on vivaldi.com's download page (the
rem highest version wins, as it also links older builds for Windows 7 and 8). The same installer can also do a
rem portable install: its Advanced options have "Install standalone", eg. into a folder on the USB)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0Installer" ^
    -Name "Vivaldi" ^
    -Page "https://vivaldi.com/download/" ^
    -Link "https://downloads\.vivaldi\.com/stable/Vivaldi\.[\d.]+\.x64\.exe" -Into "x64" ^
    -Link86 "https://downloads\.vivaldi\.com/stable/Vivaldi\.[\d.]+\.exe" -Into86 "x86" ^
    -LinkArm "https://downloads\.vivaldi\.com/stable/Vivaldi\.[\d.]+\.arm64\.exe" -IntoArm "ARM64" ^
    -Clean ^
    -MajorGeeks "vivaldi:64-Bit" -MajorGeeks86 "vivaldi:32-Bit" -MajorGeeksArm "vivaldi:ARM64"
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