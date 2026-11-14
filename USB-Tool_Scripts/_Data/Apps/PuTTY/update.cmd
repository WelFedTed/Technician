@echo off

title Updating PuTTY

rem Updates this app with the shared helper _Data\Apps\_Update-App.ps1 (see that file for the options)
rem Run it on its own, or let Update-Tool.cmd run it for every app
rem Each kind of download has its own folder here: Installer (install.cmd), Portable (run.cmd), CLI (cli.cmd)

rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
set "result=0"
set "resultRank=0"

rem Installer
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0Installer" ^
    -Name "PuTTY (installer)" ^
    -Page "https://www.chiark.greenend.org.uk/~sgtatham/putty/latest.html" ^
    -Link "https://the\.earth\.li/~sgtatham/putty/latest/w64/putty-64bit-[\d.]+-installer\.msi" -Into "x64" ^
    -Link86 "https://the\.earth\.li/~sgtatham/putty/latest/w32/putty-[\d.]+-installer\.msi" -Into86 "x86" ^
    -LinkArm "https://the\.earth\.li/~sgtatham/putty/latest/wa64/putty-arm64-[\d.]+-installer\.msi" -IntoArm "ARM64" ^
    -Clean
call :result

rem Portable
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0Portable" ^
    -Name "PuTTY (portable)" ^
    -Url "https://the.earth.li/~sgtatham/putty/latest/w64/putty.zip" -Into "x64" ^
    -Url86 "https://the.earth.li/~sgtatham/putty/latest/w32/putty.zip" -Into86 "x86" ^
    -UrlArm "https://the.earth.li/~sgtatham/putty/latest/wa64/putty.zip" -IntoArm "ARM64" ^
    -Extract -Clean ^
    -VersionFrom "x64\putty.exe"
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
