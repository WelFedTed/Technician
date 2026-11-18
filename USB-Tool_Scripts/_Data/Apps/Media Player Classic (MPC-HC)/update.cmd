@echo off

title Updating Media Player Classic (MPC-HC)

rem Updates this app with the shared helper _Data\Apps\_Update-App.ps1 (see that file for the options)
rem Run it on its own, or let Update-Tool.cmd run it for every app
rem Each kind of download has its own folder here: Installer (install.cmd), Portable (run.cmd), CLI (cli.cmd)

rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
set "result=0"
set "resultRank=0"
rem Installer (MPC-HC, the maintained Media Player Classic, by clsid2 on GitHub)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0Installer" ^
    -Name "Media Player Classic (MPC-HC) (installer)" ^
    -GitHub "clsid2/mpc-hc" ^
    -Asset "^MPC-HC\.[\d.]+\.x64\.exe$" -Into "x64" ^
    -Asset86 "^MPC-HC\.[\d.]+\.x86\.exe$" -Into86 "x86" ^
    -Clean ^
    -MajorGeeks "media_player_classic_home_cinema:64-Bit" -MajorGeeks86 "media_player_classic_home_cinema:32-Bit"
call :result

rem Portable (the same release's zips; its settings are kept on the USB once it's set to save them to an .ini file,
rem in Options > Player)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0Portable" ^
    -Name "Media Player Classic (MPC-HC) (portable)" ^
    -GitHub "clsid2/mpc-hc" ^
    -Asset "^MPC-HC\.[\d.]+\.x64\.zip$" -Into "x64" ^
    -Asset86 "^MPC-HC\.[\d.]+\.x86\.zip$" -Into86 "x86" ^
    -Extract -Flatten -Clean -Keep "*.ini" ^
    -MajorGeeks "media_player_classic_home_cinema:64-Bit Portable" -MajorGeeks86 "media_player_classic_home_cinema:32-Bit Portable"
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