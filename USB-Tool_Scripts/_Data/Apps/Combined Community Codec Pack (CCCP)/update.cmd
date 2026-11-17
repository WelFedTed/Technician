@echo off

title Updating Combined Community Codec Pack (CCCP)

rem Updates this app with the shared helper _Data\Apps\_Update-App.ps1 (see that file for the options)
rem Run it on its own, or let Update-Tool.cmd run it for every app
rem Each kind of download has its own folder here: Installer (install.cmd), Portable (run.cmd), CLI (cli.cmd)

rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
set "result=0"
set "resultRank=0"

rem Installer (saved by hand, once: discontinued in 2015 (its last version is 2015-10-18) and its site, cccp-project.net, is gone; K-Lite Codec Pack is the maintained alternative)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0Installer" ^
    -Name "Combined Community Codec Pack (CCCP)" ^
    -Manual -NoUpdates ^
    -Page "https://www.videohelp.com/software/Combined-Community-Codec-Pack" ^
    -Note "CCCP was discontinued in 2015 and its own site is gone, so only download sites still have it, and some offer modified copies. Get the final version (2015-10-18) from a site that keeps the original files, such as VideoHelp, scan it, and save it in Installer\x86. K-Lite Codec Pack (also in this tool) is kept up to date."
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
