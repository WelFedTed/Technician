@echo off

title Updating Go

rem Updates this app with the shared helper _Data\Apps\_Update-App.ps1 (see that file for the options)
rem Run it on its own, or let Update-Tool.cmd run it for every app
rem Each kind of download has its own folder here: Installer (install.cmd), Portable (run.cmd), CLI (cli.cmd)

rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
set "result=0"
set "resultRank=0"

rem Installer (from go.dev's list of the current stable releases)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0Installer" ^
    -Name "Go (installer)" ^
    -Page "https://go.dev/dl/?mode=json" ^
    -Link "go[\d.]+\.windows-amd64\.msi" -Into "x64" ^
    -Link86 "go[\d.]+\.windows-386\.msi" -Into86 "x86" ^
    -LinkArm "go[\d.]+\.windows-arm64\.msi" -IntoArm "ARM64" ^
    -VersionFromUrl -Clean
call :result

rem CLI (the whole Go toolchain, which runs from its folder)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0CLI" ^
    -Name "Go (command line)" ^
    -Page "https://go.dev/dl/?mode=json" ^
    -Link "go[\d.]+\.windows-amd64\.zip" -Into "x64" ^
    -Link86 "go[\d.]+\.windows-386\.zip" -Into86 "x86" ^
    -LinkArm "go[\d.]+\.windows-arm64\.zip" -IntoArm "ARM64" ^
    -Extract -Flatten -Clean
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
