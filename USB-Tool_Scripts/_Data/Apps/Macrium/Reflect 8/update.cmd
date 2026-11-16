@echo off

title Updating Macrium Reflect 8

rem Updates this app with the shared helper _Data\Apps\_Update-App.ps1 (see that file for the options)
rem Run it on its own, or let Update-Tool.cmd run it for every app
rem Each kind of download has its own folder here: Installer (install.cmd), Portable (run.cmd), CLI (cli.cmd)

rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
set "result=0"
set "resultRank=0"

rem Installer (saved by hand, once: the free edition was discontinued at v8.0.7167 and gets no more updates)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\..\_Update-App.ps1" -AppDir "%~dp0Installer" ^
    -Name "Macrium Reflect 8" ^
    -Manual -NoUpdates ^
    -Page "https://www.macrium.com/reflectfree" ^
    -Note "Macrium discontinued Reflect Free (its last version is 8.0.7167, with no security fixes since January 2024) and no longer offers it. If you save its installer from another site (eg. MajorGeeks), check that it's digitally signed by Paramount Software UK Ltd, then put it in Installer\x64."
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
