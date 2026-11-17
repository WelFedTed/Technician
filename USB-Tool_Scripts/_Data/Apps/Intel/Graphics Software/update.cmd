@echo off

title Updating Intel Graphics Software

rem Updates this app with the shared helper _Data\Apps\_Update-App.ps1 (see that file for the options)
rem Run it on its own, or let Update-Tool.cmd run it for every app
rem Each kind of download has its own folder here: Installer (install.cmd), Portable (run.cmd), CLI (cli.cmd)

rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
set "result=0"
set "resultRank=0"

rem Installer (Intel's Arc / Iris Xe graphics driver, which comes with Intel Graphics Software)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\..\_Update-App.ps1" -AppDir "%~dp0Installer" ^
    -Name "Intel Graphics Software" ^
    -Page "https://www.intel.com/content/www/us/en/download/785597.html" ^
    -Link "https://downloadmirror\.intel\.com/\d+/gfx_win_[\d.]+\.exe" -Into "x64" ^
    -UserAgent "curl/8.0" ^
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
