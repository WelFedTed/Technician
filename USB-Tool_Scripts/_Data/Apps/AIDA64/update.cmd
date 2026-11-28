@echo off

title Updating AIDA64

rem Updates this app with the shared helper _Data\Apps\_Update-App.ps1 (see that file for the options)
rem Run it on its own, or let Update-Tool.cmd run it for every app
rem Each kind of download has its own folder here: Installer (install.cmd), Portable (run.cmd), CLI (cli.cmd)

rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
set "result=0"
set "resultRank=0"

rem Portable (AIDA64 Extreme's portable ZIP, for 64-bit Windows. It's paid software: unregistered, it runs as a
rem 30-day trial that hides some values. Windows asks for admin rights when it starts, which it needs to read
rem the sensors. Its settings stay in aida64.ini next to it, kept when updating)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0Portable" ^
    -Name "AIDA64 Extreme (portable, trial)" ^
    -PageIndex "https://www.aida64.com/downloads" ^
    -PageIndexLink "(?s)href=.downloads/([A-Za-z0-9+/]+=*).>AIDA64 Extreme </a>(?:(?!</tr>).)*?portable ZIP package" ^
    -Page "https://www.aida64.com/downloads/{0}" ^
    -Link "https://download\.aida64\.com/aida64extreme\d+\.zip" ^
    -Into "x64" -Extract -Clean -Keep "aida64.ini" ^
    -VersionFrom "x64\aida64.exe" ^
    -MajorGeeks "aida64_extreme_edition:Portable"
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
