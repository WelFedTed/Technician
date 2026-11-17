@echo off

title Updating PowerShell 7

rem Updates this app with the shared helper _Data\Apps\_Update-App.ps1 (see that file for the options)
rem Run it on its own, or let Update-Tool.cmd run it for every app
rem Each kind of download has its own folder here: Installer (install.cmd), Portable (run.cmd), CLI (cli.cmd)

rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
set "result=0"
set "resultRank=0"

rem Installer (the 7.6 LTS MSIs, as PowerShell 7.7 and later only come as an msixbundle; install.cmd runs Microsoft's own installer script from the web first)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\..\_Update-App.ps1" -AppDir "%~dp0Installer" ^
    -Name "PowerShell 7 (installer)" ^
    -Page "https://github.com/PowerShell/PowerShell/releases" ^
    -GitHub "PowerShell/PowerShell" -PreRelease -SkipPreReleases ^
    -Asset "^PowerShell-7\.6\.[\d.]+-win-x64\.msi$" -Into "x64" ^
    -AssetArm "^PowerShell-7\.6\.[\d.]+-win-arm64\.msi$" -IntoArm "ARM64" ^
    -Clean
call :result

rem Portable (the latest version, which runs from the USB (pwsh.exe))
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\..\_Update-App.ps1" -AppDir "%~dp0Portable" ^
    -Name "PowerShell 7" ^
    -GitHub "PowerShell/PowerShell" ^
    -Asset "^PowerShell-[\d.]+-win-x64\.zip$" -Into "x64" ^
    -Asset86 "^PowerShell-[\d.]+-win-x86\.zip$" -Into86 "x86" ^
    -AssetArm "^PowerShell-[\d.]+-win-arm64\.zip$" -IntoArm "ARM64" ^
    -Extract -Clean
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
