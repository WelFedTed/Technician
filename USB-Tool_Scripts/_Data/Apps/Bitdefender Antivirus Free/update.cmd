@echo off

title Updating Bitdefender Antivirus Free

rem Updates this app with the shared helper _Data\Apps\_Update-App.ps1 (see that file for the options)
rem Run it on its own, or let Update-Tool.cmd run it for every app
rem Each kind of download has its own folder here: Installer (install.cmd), Portable (run.cmd), CLI (cli.cmd)

rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
set "result=0"
set "resultRank=0"

rem Installer (Bitdefender Antivirus Free, from Bitdefender's own download link: a small setup that downloads
rem the latest version while installing, so it needs internet. It's kept in x86, as it runs on any Windows
rem and installs the right build itself. No MajorGeeks backup: MajorGeeks' link for it goes through an
rem affiliate tracker, not to the file)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0Installer" ^
    -Name "Bitdefender Antivirus Free (installer)" ^
    -Page "https://www.bitdefender.com/en-us/consumer/free-antivirus" ^
    -Url "https://download.bitdefender.com/windows/installer/en-us/bitdefender_avfree.exe" -Into "x86" ^
    -Clean
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