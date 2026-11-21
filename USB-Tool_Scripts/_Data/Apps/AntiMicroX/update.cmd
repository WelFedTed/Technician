@echo off

title Updating AntiMicroX

rem Updates this app with the shared helper _Data\Apps\_Update-App.ps1 (see that file for the options)
rem Run it on its own, or let Update-Tool.cmd run it for every app
rem Each kind of download has its own folder here: Installer (install.cmd), Portable (run.cmd), CLI (cli.cmd)

rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
set "result=0"
set "resultRank=0"

rem Installer (AntiMicroX, from its GitHub releases: maps keyboard keys and mouse controls to a gamepad. It's the
rem maintained successor of the original AntiMicro, whose repo is archived. 64-bit only; ARM64 PCs run it too)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0Installer" ^
    -Name "AntiMicroX (installer)" ^
    -GitHub "AntiMicroX/antimicrox" ^
    -Asset "^antimicrox-[\d.]+-Windows-AMD64\.exe$" -Into "x64" ^
    -Clean ^
    -MajorGeeks "antimicrox:EXE"
call :result

rem Portable (the release's portable zip, built with AntiMicroX's PORTABLE_WIN option so it keeps its settings
rem next to the program, which an update replaces; run.cmd starts its bin\antimicrox.exe)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0Portable" ^
    -Name "AntiMicroX (portable)" ^
    -GitHub "AntiMicroX/antimicrox" ^
    -Asset "^antimicrox-[\d.]+-PortableWindows-AMD64\.zip$" -Into "x64" ^
    -Extract -Flatten -Clean ^
    -MajorGeeks "antimicrox:Portable"
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