@echo off

title Updating System Information Viewer (SIV)

rem Updates this app with the shared helper _Data\Apps\_Update-App.ps1 (see that file for the options)
rem Run it on its own, or let Update-Tool.cmd run it for every app
rem Each kind of download has its own folder here: Installer (install.cmd), Portable (run.cmd), CLI (cli.cmd)

rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
set "result=0"
set "resultRank=0"

rem Portable (SIV, Ray Hinchliffe's System Information Viewer: detailed hardware details and live sensor readings.
rem The zip from rh-software.com, whose page links the current version's siv_v<version>.zip (over http, as the
rem site's https certificate isn't trusted). It holds a build for each kind of Windows that share their files:
rem SIV64X.exe for 64-bit Windows, SIV32X.exe for 32-bit Windows 2000 and later, and others for older Windows and
rem other processors (NT4, Windows 9x, Itanium, Alpha, PowerPC), so it's kept in x86_x64 and run.cmd picks
rem between them. There's no ARM64 build, so ARM64 Windows runs SIV64X.exe. It asks for admin rights itself, which
rem it needs for full detail)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0Portable" ^
    -Name "System Information Viewer (SIV)" ^
    -Page "http://rh-software.com/" ^
    -Link "zip[\\/]siv_v([\d.]+)\.zip" -UrlFormat "http://rh-software.com/zip/siv_v{0}.zip" -Into "x86_x64" ^
    -Extract -Clean ^
    -MajorGeeks "siv_(system_information_viewer)"
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