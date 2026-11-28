@echo off

title Updating smartmontools

rem Updates this app with the shared helper _Data\Apps\_Update-App.ps1 (see that file for the options)
rem Run it on its own, or let Update-Tool.cmd run it for every app
rem Each kind of download has its own folder here: Installer (install.cmd), Portable (run.cmd), CLI (cli.cmd)

rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
set "result=0"
set "resultRank=0"

rem Installer (installs smartctl and the smartd service; MajorGeeks' backup may be an older version)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0Installer" ^
    -Name "smartmontools (installer)" ^
    -Page "https://github.com/smartmontools/smartmontools/releases/latest" ^
    -GitHub "smartmontools/smartmontools" -Asset "^smartmontools-[\d.]+(-\d+)?\.win32-setup\.exe$" -Into "x86" ^
    -Clean ^
    -VersionFrom "x86\smartmontools-*.win32-setup.exe" ^
    -MajorGeeks "smartmontools"
call :result

rem CLI (the same installer, unpacked: bin\ holds the 64-bit tools (smartctl, smartd), bin32\ the 32-bit ones,
rem doc\ the manuals. cli.cmd opens a prompt in bin\ as admin, as smartctl needs admin rights to read the disks.
rem The tags are named eg. RELEASE_7_5, so the version is read from smartctl.exe)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0CLI" ^
    -Name "smartmontools (command line)" ^
    -Page "https://github.com/smartmontools/smartmontools/releases/latest" ^
    -GitHub "smartmontools/smartmontools" -Asset "^smartmontools-[\d.]+(-\d+)?\.win32-setup\.exe$" -Into "x64" ^
    -Paf -Clean ^
    -VersionFrom "x64\bin\smartctl.exe"
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
