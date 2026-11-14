@echo off

title Updating NVIDIA App

rem Updates this app with the shared helper _Data\Apps\_Update-App.ps1 (see that file for the options)
rem Run it on its own, or let Update-Tool.cmd run it for every app
rem Each kind of download has its own folder here: Installer (install.cmd), Portable (run.cmd), CLI (cli.cmd)

rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
set "result=0"
set "resultRank=0"

rem Installer
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0Installer" -MoveFrom "%~dp0..\Nvida App" ^
    -Name "NVIDIA App" ^
    -Page "https://www.nvidia.com/en-us/software/nvidia-app/" ^
    -Link "https://us\.download\.nvidia\.com/nvapp/client/[\d.]+/x64/NVIDIA_app_v[\d.]+_x64\.exe" ^
    -LinkArm "https://us\.download\.nvidia\.com/nvapp/client/[\d.]+/arm64/NVIDIA_app_v[\d.]+_arm64\.exe" ^
    -Into "x64" -IntoArm "ARM64" -Clean
call :result

rem run.cmd from the old layout (this app has no portable version, so it has install.cmd or cli.cmd instead)
if exist "%~dp0run.cmd" del "%~dp0run.cmd"

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
