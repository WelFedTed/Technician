@echo off

title Updating Mem Reduct

rem Updates this app with the shared helper _Data\Apps\_Update-App.ps1 (see that file for the options)
rem Run it on its own, or let Update-Tool.cmd run it for every app
rem Each kind of download has its own folder here: Installer (install.cmd), Portable (run.cmd), CLI (cli.cmd)

rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
set "result=0"
set "resultRank=0"

rem Installer (Mem Reduct, henrypp's memory cleaner, from its GitHub releases. A 32-bit setup holding the 64-bit
rem and 32-bit builds, which installs the right one itself, so it's kept in x86. It isn't code-signed: henrypp
rem signs his files with the .sig files next to them instead)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0Installer" ^
    -Name "Mem Reduct (installer)" ^
    -GitHub "henrypp/memreduct" ^
    -Asset "^memreduct-[\d.]+-setup\.exe$" -Into "x86" ^
    -Clean ^
    -MajorGeeks "mem_reduct:EXE"
call :result

rem Portable (the same release's -bin.7z holds every build, in its 32, 64 and arm64 folders, so each build folder
rem takes its own. The portable.dat in each one keeps Mem Reduct in portable mode, with its settings in the
rem memreduct.ini next to it, kept when updating. MajorGeeks only has the setup, so there's no backup for these)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0Portable" ^
    -Name "Mem Reduct (portable)" ^
    -GitHub "henrypp/memreduct" ^
    -Asset "^memreduct-[\d.]+-bin\.7z$" -Inner "memreduct\64" -Into "x64" ^
    -Asset86 "^memreduct-[\d.]+-bin\.7z$" -Inner86 "memreduct\32" -Into86 "x86" ^
    -AssetArm "^memreduct-[\d.]+-bin\.7z$" -InnerArm "memreduct\arm64" -IntoArm "ARM64" ^
    -Extract -Clean -Keep "memreduct.ini,portable.dat"
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
