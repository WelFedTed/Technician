@echo off

title Updating Cheat Engine

rem Updates this app with the shared helper _Data\Apps\_Update-App.ps1 (see that file for the options)
rem Run it on its own, or let Update-Tool.cmd run it for every app
rem Each kind of download has its own folder here: Installer (install.cmd), Portable (run.cmd), CLI (cli.cmd)

rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
set "result=0"
set "resultRank=0"
rem Installer (Cheat Engine, by Dark Byte (Cheat Engine EZ): a memory scanner, debugger and game modding tool.
rem cheatengine.org's own download button gives a small downloader signed by another company (Synaptix Global), which
rem offers third-party software before it fetches the real setup, and the GitHub releases have no downloads (and
rem stop at 7.5). So this is the real setup, signed by Cheat Engine EZ, from the address that downloader uses;
rem the link (it changes with each release) is read from Chocolatey's cheatengine package page. The setup may still
rem offer extra software itself (cheatengine.org says only its Patreon download has none): untick them when
rem installing. It's a 32-bit setup that installs the 32-bit and 64-bit builds, so it's kept in x86. No MajorGeeks
rem backup: MajorGeeks has no page for Cheat Engine. (Antivirus apps often flag Cheat Engine, and its kernel driver
rem is unsigned, so it only loads with driver signature checks turned off)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0Installer" ^
    -Name "Cheat Engine" ^
    -Page "https://community.chocolatey.org/packages/cheatengine" ^
    -Link "https://d1dj9aohuk02ls\.cloudfront\.net/f/CheatEngine/\d+/CheatEngine\d+\.exe" -Into "x86" ^
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