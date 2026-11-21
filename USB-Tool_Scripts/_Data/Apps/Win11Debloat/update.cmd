@echo off

title Updating Win11Debloat

rem Updates this app with the shared helper _Data\Apps\_Update-App.ps1 (see that file for the options)
rem Run it on its own, or let Update-Tool.cmd run it for every app
rem Each kind of download has its own folder here: Installer (install.cmd), Portable (run.cmd), CLI (cli.cmd)

rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
set "result=0"
set "resultRank=0"
rem Portable (Win11Debloat, by Raphire on GitHub: a PowerShell script, with a menu, that removes preinstalled apps,
rem turns off telemetry, ads and AI features, and changes other settings in Windows 10 and 11. The release's
rem Win11Debloat.zip, for when the web version (irm https://debloat.raphi.re/ | iex) can't be reached. Its logs and
rem saved settings are kept in the PC's %LOCALAPPDATA%\Win11Debloat, not on the USB)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0Portable" ^
    -Name "Win11Debloat" ^
    -Page "https://github.com/Raphire/Win11Debloat" ^
    -GitHub "Raphire/Win11Debloat" -Asset "^Win11Debloat\.zip$" -Into "Any" ^
    -Extract -Flatten -Clean ^
    -MajorGeeks "windows10debloater_103z"
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