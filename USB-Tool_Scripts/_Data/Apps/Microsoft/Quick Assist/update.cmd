@echo off

title Updating Quick Assist

rem Updates this app with the shared helper _Data\Apps\_Update-App.ps1 (see that file for the options)
rem Run it on its own, or let Update-Tool.cmd run it for every app
rem Each kind of download has its own folder here: Installer (install.cmd), Portable (run.cmd), CLI (cli.cmd)

rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
set "result=0"
set "resultRank=0"

rem Installer (Microsoft's remote help app. Windows 11 and recent Windows 10 already have it, but it can be missing
rem or removed. It only comes from the Microsoft Store: this small installer gets it from the Store, so it needs the internet.
rem No MajorGeeks backup: its page only links to the Store's web page)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\..\_Update-App.ps1" -AppDir "%~dp0Installer" ^
    -Name "Quick Assist (Microsoft Store installer)" ^
    -Page "https://apps.microsoft.com/detail/9P7BP5VNWKX5" ^
    -Url "https://get.microsoft.com/installer/download/9P7BP5VNWKX5" ^
    -SaveAs "Quick Assist Installer.exe" -Into "Any"
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
