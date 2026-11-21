@echo off

title Updating Wise Care 365

rem Updates this app with the shared helper _Data\Apps\_Update-App.ps1 (see that file for the options)
rem Run it on its own, or let Update-Tool.cmd run it for every app
rem Each kind of download has its own folder here: Installer (install.cmd), Portable (run.cmd), CLI (cli.cmd)

rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
set "result=0"
set "resultRank=0"

rem Installer (Wise Care 365 Free, from WiseCleaner's own download link, which always gives the latest release.
rem It's a 32-bit setup, so it's kept in x86. No MajorGeeks backup: MajorGeeks' links for it go to WiseCleaner's
rem store page, not the file)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0Installer" ^
    -Name "Wise Care 365 (installer)" ^
    -Page "https://www.wisecleaner.com/wise-care-365.html" ^
    -Url "https://downloads.wisecleaner.com/soft/WiseCare365.exe" -Into "x86" ^
    -Clean
call :result

rem Portable (WiseCleaner's portable zip, which holds a WiseCare365_<version>(x64) and a (x86) folder; run.cmd
rem picks between them. Its settings are kept in those folders, which an update replaces)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0Portable" ^
    -Name "Wise Care 365 (portable)" ^
    -Page "https://www.wisecleaner.com/wise-care-365.html" ^
    -Url "https://downloads.wisecleaner.com/soft/WiseCare365.zip" -Into "x86_x64" ^
    -Extract -Flatten -Clean ^
    -VersionFrom "x86_x64\WiseCare365_*(x64)\WiseCare365.exe"
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