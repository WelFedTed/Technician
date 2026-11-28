@echo off

title Updating WhyNotWin11

rem Updates this app with the shared helper _Data\Apps\_Update-App.ps1 (see that file for the options)
rem Run it on its own, or let Update-Tool.cmd run it for every app
rem Each kind of download has its own folder here: Installer (install.cmd), Portable (run.cmd), CLI (cli.cmd)

rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
set "result=0"
set "resultRank=0"

rem Portable (a 64-bit and a 32-bit build, one exe each. It runs without admin rights, but its TPM check is only
rem complete as admin, so run.cmd starts it as admin. MajorGeeks' backup is one build: either runs on 64-bit Windows)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0Portable" ^
    -Name "WhyNotWin11" ^
    -Page "https://github.com/rcmaehl/WhyNotWin11/releases/latest" ^
    -GitHub "rcmaehl/WhyNotWin11" ^
    -Asset "^WhyNotWin11\.exe$" -Into "x64" ^
    -Asset86 "^WhyNotWin11_x86\.exe$" -Into86 "x86" -SaveAs86 "WhyNotWin11.exe" ^
    -Clean ^
    -MajorGeeks "whynotwin11"
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
