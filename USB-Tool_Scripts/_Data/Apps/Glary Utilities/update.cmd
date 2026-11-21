@echo off

title Updating Glary Utilities

rem Updates this app with the shared helper _Data\Apps\_Update-App.ps1 (see that file for the options)
rem Run it on its own, or let Update-Tool.cmd run it for every app
rem Each kind of download has its own folder here: Installer (install.cmd), Portable (run.cmd), CLI (cli.cmd)

rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
set "result=0"
set "resultRank=0"

rem Installer (Glary Utilities Free, from Glarysoft's own download link, which always gives the latest release.
rem It's a 32-bit setup that installs the right build itself, so it's kept in x86. No MajorGeeks backup for either
rem download: MajorGeeks' links for them go to Glarysoft's store page, not the file)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0Installer" ^
    -Name "Glary Utilities (installer)" ^
    -Page "https://www.glarysoft.com/glary-utilities/" ^
    -Url "https://download.glarysoft.com/gusetup.exe" -Into "x86" ^
    -Clean
call :result

rem Portable (Glarysoft's portable version, a self-extracting 7-Zip file, unpacked here: Integrator_Portable.exe
rem starts it, from a 32-bit program with an x64 folder of helpers for 64-bit Windows. Its settings are kept in
rem its Portable\settings.ini and Portable\data, which an update replaces)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0Portable" ^
    -Name "Glary Utilities (portable)" ^
    -Page "https://www.glarysoft.com/glary-utilities/" ^
    -Url "https://download.glarysoft.com/guportable.exe" -Into "x86" ^
    -Extract -Sfx -Flatten -Clean ^
    -VersionFrom "x86\Portable\Integrator.exe"
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