@echo off

title Updating eM Client

rem Updates this app with the shared helper _Data\Apps\_Update-App.ps1 (see that file for the options)
rem Run it on its own, or let Update-Tool.cmd run it for every app
rem Each kind of download has its own folder here: Installer (install.cmd), Portable (run.cmd), CLI (cli.cmd)

rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
set "result=0"
set "resultRank=0"

rem Installer (eM Client 11 only comes as an MSIX bundle, about 890 MB, holding the x64, x86 and ARM64 builds;
rem the link and its SHA256 come from winget's listing. Its 1.6 MB setup.msi is only an online updater, and
rem MajorGeeks has an MSI, not this bundle, so there's no backup. Opening the bundle installs it for the current
rem user, with App Installer)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0Installer" ^
    -Name "eM Client (installer)" ^
    -Page "https://www.emclient.com/download" ^
    -Winget "eMClient.eMClient" -WingetType "msix" -Into "Any" ^
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
