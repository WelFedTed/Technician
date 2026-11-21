@echo off

title Updating AutoHotkey

rem Updates this app with the shared helper _Data\Apps\_Update-App.ps1 (see that file for the options)
rem Run it on its own, or let Update-Tool.cmd run it for every app
rem Each kind of download has its own folder here: Installer (install.cmd), Portable (run.cmd), CLI (cli.cmd)

rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
set "result=0"
set "resultRank=0"

rem Installer (AutoHotkey v2, from its GitHub releases: the setup installs for the current user or for everyone,
rem and asks for admin itself when needed; it runs on x86, x64 and ARM64 Windows, so it's kept in x86)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0Installer" ^
    -Name "AutoHotkey (installer)" ^
    -GitHub "AutoHotkey/AutoHotkey" ^
    -Asset "^AutoHotkey_[\d.]+_setup\.exe$" -Into "x86" ^
    -Clean ^
    -MajorGeeks "autohotkey:EXE"
call :result

rem Portable (the same release's zip: AutoHotkey32.exe and AutoHotkey64.exe side by side, which run.cmd picks
rem between; ARM64 Windows runs the 64-bit one. Pass a script to run it, eg. run.cmd "D:\Scripts\MyScript.ahk")
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0Portable" ^
    -Name "AutoHotkey (portable)" ^
    -GitHub "AutoHotkey/AutoHotkey" ^
    -Asset "^AutoHotkey_[\d.]+\.zip$" -Into "x86_x64" ^
    -Extract -Clean ^
    -MajorGeeks "autohotkey:Portable"
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