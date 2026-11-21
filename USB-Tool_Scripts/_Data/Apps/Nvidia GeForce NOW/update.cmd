@echo off

title Updating Nvidia GeForce NOW

rem Updates this app with the shared helper _Data\Apps\_Update-App.ps1 (see that file for the options)
rem Run it on its own, or let Update-Tool.cmd run it for every app
rem Each kind of download has its own folder here: Installer (install.cmd), Portable (run.cmd), CLI (cli.cmd)

rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
set "result=0"
set "resultRank=0"

rem Installer (NVIDIA GeForce NOW, the cloud gaming app: NVIDIA's installer as winget lists it, which gives the
rem app's version and the file's checksum (the download page's own link is unversioned, and the installer exe
rem carries its own version, not the app's). It needs 64-bit Windows, so it's kept in x64, which install.cmd also
rem looks in on ARM64)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0Installer" ^
    -Name "NVIDIA GeForce NOW" ^
    -Page "https://www.nvidia.com/en-us/geforce-now/download/" ^
    -Winget "Nvidia.GeForceNow" -Into "x64" ^
    -Clean ^
    -MajorGeeks "geforce-now:EXE"
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