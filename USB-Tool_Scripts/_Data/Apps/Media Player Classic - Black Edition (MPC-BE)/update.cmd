@echo off

title Updating Media Player Classic - Black Edition (MPC-BE)

rem Updates this app with the shared helper _Data\Apps\_Update-App.ps1 (see that file for the options)
rem Run it on its own, or let Update-Tool.cmd run it for every app
rem Each kind of download has its own folder here: Installer (install.cmd), Portable (run.cmd), CLI (cli.cmd)

rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
set "result=0"
set "resultRank=0"

rem Installer (MPC-BE, a media player based on Media Player Classic, by Aleksoid1978 on GitHub: the release's
rem x64 and x86 installers, each in a zip that's unzipped here)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0Installer" ^
    -Name "Media Player Classic - Black Edition (MPC-BE) (installer)" ^
    -GitHub "Aleksoid1978/MPC-BE" ^
    -Asset "^MPC-BE\.[\d.]+\.x64-installer\.zip$" -Into "x64" ^
    -Asset86 "^MPC-BE\.[\d.]+\.x86-installer\.zip$" -Into86 "x86" ^
    -Extract -Clean ^
    -MajorGeeks "media_player_classic_black_edition_(mpc_be)_64_bit" -MajorGeeks86 "media_player_classic_black_edition"
call :result

rem Portable (the same release's 7z files; its settings are kept on the USB once it's set to save them to an .ini
rem file, in Options > Player. MajorGeeks only has the installers, so there's no backup for these)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0Portable" ^
    -Name "Media Player Classic - Black Edition (MPC-BE) (portable)" ^
    -GitHub "Aleksoid1978/MPC-BE" ^
    -Asset "^MPC-BE\.[\d.]+\.x64\.7z$" -Into "x64" ^
    -Asset86 "^MPC-BE\.[\d.]+\.x86\.7z$" -Into86 "x86" ^
    -Extract -Flatten -Clean -Keep "*.ini"
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
