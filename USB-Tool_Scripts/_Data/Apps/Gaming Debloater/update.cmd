@echo off

title Updating Gaming Debloater

rem Updates this app with the shared helper _Data\Apps\_Update-App.ps1 (see that file for the options)
rem Run it on its own, or let Update-Tool.cmd run it for every app
rem Each kind of download has its own folder here: Installer (install.cmd), Portable (run.cmd), CLI (cli.cmd)

rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
set "result=0"
set "resultRank=0"

rem Portable (Gaming Debloater, by FreeTimeTech: a version of their Windows 11 Debloater with gaming, GPU and
rem quality-of-life tweaks, based on DaddyMadu's Windows10GamingFocus scripts. GamingDebloater.exe (64-bit,
rem .NET 4.7.2, needs admin) builds a PowerShell script from the options in its .txt files and can run it.
rem From FreeTimeTech's own link to version 1.4 (Jan 2024): its page, freetimetech.com/gaming-debloater/, is gone, so
rem a newer version wouldn't be found here; MajorGeeks' copy is the backup)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0Portable" ^
    -Name "Gaming Debloater" ^
    -Url "https://freetimetech.com/software/gd/GamingDebloaterV14.zip" -Into "x64" ^
    -Extract -Flatten -Clean ^
    -VersionFrom "x64\GamingDebloater.exe" ^
    -MajorGeeks "gaming_debloater"
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
