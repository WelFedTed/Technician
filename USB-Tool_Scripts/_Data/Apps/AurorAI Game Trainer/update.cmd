@echo off

title Updating AurorAI Game Trainer

rem Updates this app with the shared helper _Data\Apps\_Update-App.ps1 (see that file for the options)
rem Run it on its own, or let Update-Tool.cmd run it for every app
rem Each kind of download has its own folder here: Installer (install.cmd), Portable (run.cmd), CLI (cli.cmd)

rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
set "result=0"
set "resultRank=0"
rem Portable (AurorAI, formerly Aurora, by Cheat Happens: a trainer manager for single-player PC games. Its free
rem trainers need no membership; the others need a Cheat Happens premium account. From Cheat Happens' own fixed
rem link for the portable version, the one its trainers page's "Download AurorAI (Portable)" button gives after
rem ticking its privacy policy box. A 64-bit app, so it's kept in x64. The exe holds the version: the trainers page
rem shows an older number. The installer isn't kept: it's a 2 MB online installer that downloads this same zip.
rem Aurora.exe asks for admin itself. It also has its own Updater.exe, which can update the copy on the USB too)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0Portable" ^
    -Name "AurorAI Game Trainer" ^
    -Page "https://www.cheathappens.com/trainers.asp" ^
    -Url "https://www.ch-downloads.com/TM/Aurora.zip" -Into "x64" ^
    -Extract -Clean ^
    -VersionFrom "x64\Aurora.exe" ^
    -MajorGeeks "aurora"
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