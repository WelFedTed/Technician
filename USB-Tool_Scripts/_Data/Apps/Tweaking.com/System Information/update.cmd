@echo off

title Updating Tweaking.com - System Information

rem Updates this app with the shared helper _Data\Apps\_Update-App.ps1 (see that file for the options)
rem Run it on its own, or let Update-Tool.cmd run it for every app
rem Each kind of download has its own folder here: Installer (install.cmd), Portable (run.cmd), CLI (cli.cmd)

rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
set "result=0"
set "resultRank=0"

rem Portable (Tweaking.com's System Information 1.0.2: a quick text report of the PC's hardware, software, drivers,
rem services and startup items. Tweaking.com no longer updates it (unchanged since 2016) and its page now links only
rem to MajorGeeks' copy, but the program is still on Tweaking.com's download server, under the name it always had
rem there. The download is a self-extracting archive that unpacks the program to a folder and runs it, so it's
rem unpacked here instead: System_Information.exe, a 32-bit program that asks for admin rights itself. Its settings
rem are kept in its settings.ini, which an update replaces)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\..\_Update-App.ps1" -AppDir "%~dp0Portable" ^
    -Name "Tweaking.com - System Information" ^
    -Page "https://www.tweaking.com/features/system-information/" ^
    -Url "https://www.tweaking.com/files/setups/Tweaking.com-System_Information.exe" -Into "x86" ^
    -Extract -Sfx -Flatten -Clean ^
    -VersionFrom "x86\System_Information.exe" ^
    -MajorGeeks "tweaking_com_system_information"
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