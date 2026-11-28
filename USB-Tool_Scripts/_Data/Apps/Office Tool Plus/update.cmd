@echo off

title Updating Office Tool Plus

rem Updates this app with the shared helper _Data\Apps\_Update-App.ps1 (see that file for the options)
rem Run it on its own, or let Update-Tool.cmd run it for every app
rem Each kind of download has its own folder here: Installer (install.cmd), Portable (run.cmd), CLI (cli.cmd)

rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
set "result=0"
set "resultRank=0"

rem Portable (installs, repairs, activates and removes Office. The build "with runtime" includes .NET, so it runs on
rem any PC; there's no 32-bit build any more)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0Portable" ^
    -Name "Office Tool Plus" ^
    -Page "https://github.com/YerongAI/Office-Tool/releases/latest" ^
    -GitHub "YerongAI/Office-Tool" ^
    -Asset "^Office_Tool_with_runtime_v[\d.]+_x64\.zip$" -Into "x64" ^
    -AssetArm "^Office_Tool_with_runtime_v[\d.]+_arm64\.zip$" -IntoArm "ARM64" ^
    -Extract -Flatten -Clean ^
    -MajorGeeks "office_tool_plus:64-Bit" -MajorGeeksArm "office_tool_plus:ARM64"
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
