@echo off

title Updating foobar2000

rem Updates this app with the shared helper _Data\Apps\_Update-App.ps1 (see that file for the options)
rem Run it on its own, or let Update-Tool.cmd run it for every app
rem Each kind of download has its own folder here: Installer (install.cmd), Portable (run.cmd), CLI (cli.cmd)

rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
set "result=0"
set "resultRank=0"

rem Installer (foobar2000, the audio player: the x64, x86 and ARM64 (ARM64EC) installers, from the versioned links
rem on foobar2000.org's Windows download page, which download directly. There's no separate portable download:
rem the installer itself offers a portable install, into a folder of your choice, with its settings kept there)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0Installer" ^
    -Name "foobar2000" ^
    -Page "https://www.foobar2000.org/windows" ^
    -Link "/downloads/foobar2000-x64_v[\d.]+\.exe" -Into "x64" ^
    -Link86 "/downloads/foobar2000_v[\d.]+\.exe" -Into86 "x86" ^
    -LinkArm "/downloads/foobar2000-arm64ec_v[\d.]+\.exe" -IntoArm "ARM64" ^
    -Clean ^
    -MajorGeeks "foobar2000:64-Bit" -MajorGeeks86 "foobar2000:32-Bit" -MajorGeeksArm "foobar2000:ARM64"
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
