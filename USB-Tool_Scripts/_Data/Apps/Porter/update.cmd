@echo off

title Updating Porter

rem Updates this app with the shared helper _Data\Apps\_Update-App.ps1 (see that file for the options)
rem Run it on its own, or let Update-Tool.cmd run it for every app
rem Each kind of download has its own folder here: Installer (install.cmd), Portable (run.cmd), CLI (cli.cmd)

rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
set "result=0"
set "resultRank=0"

rem Installer (64-bit only; it also puts porter, the command line, on the PATH. No MajorGeeks backup: it isn't listed there)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0Installer" ^
    -Name "Porter (installer)" ^
    -Page "https://github.com/t21dev/porter-app/releases/latest" ^
    -GitHub "t21dev/porter-app" -Asset "^Porter_[\d.]+_x64-setup\.exe$" -Into "x64" ^
    -Clean
call :result

rem Portable (the app, Porter.exe, and the command line, cli\porter.exe, which cli.cmd opens a prompt for.
rem The "portable" file next to Porter.exe keeps its settings and pinned ports in the data folder beside it.
rem It needs the WebView2 Runtime, which Windows 10 and 11 already have, and admin rights to stop processes
rem and see every port's owner, so run.cmd and cli.cmd start it as admin)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0Portable" ^
    -Name "Porter (portable)" ^
    -Page "https://github.com/t21dev/porter-app/releases/latest" ^
    -GitHub "t21dev/porter-app" -Asset "^Porter_[\d.]+_x64_portable\.zip$" -Into "x64" ^
    -Extract -Flatten -Clean -Keep "data"
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
