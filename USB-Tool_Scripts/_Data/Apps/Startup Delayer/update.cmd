@echo off

title Updating Startup Delayer

rem Updates this app with the shared helper _Data\Apps\_Update-App.ps1 (see that file for the options)
rem Run it on its own, or let Update-Tool.cmd run it for every app
rem Each kind of download has its own folder here: Installer (install.cmd), Portable (run.cmd), CLI (cli.cmd)

rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
set "result=0"
set "resultRank=0"
rem Installer (Startup Delayer 4, by Codebit Labs, who took it over from r2 Studios: www.r2.com.au now sends you to
rem startupdelayer.com. Its download page reads the version from download-manifest.json, so this does too. 64-bit
rem Windows only, and it needs the .NET 10 Desktop Runtime, which its setup downloads if the PC doesn't have it.
rem The old Startup Delayer 3, now "Classic", is only downloadable from a customer account)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0Installer" ^
    -Name "Startup Delayer (installer)" ^
    -Page "https://downloads.startupdelayer.com/download-manifest.json" ^
    -Link "version\W{1,5}(\d+(?:\.\d+)+)" ^
    -UrlFormat "https://downloads.startupdelayer.com/versions/{0}/StartupDelayer4-win-Setup.exe" -Into "x64" ^
    -Clean ^
    -MajorGeeks "startup_delayer"
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