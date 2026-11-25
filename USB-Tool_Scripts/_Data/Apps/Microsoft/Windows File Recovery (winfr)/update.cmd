@echo off

title Updating Windows File Recovery (winfr)

rem Updates this app with the shared helper _Data\Apps\_Update-App.ps1 (see that file for the options)
rem Run it on its own, or let Update-Tool.cmd run it for every app
rem Each kind of download has its own folder here: Installer (install.cmd), Portable (run.cmd), CLI (cli.cmd)

rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
set "result=0"
set "resultRank=0"

rem Installer (Windows File Recovery, Microsoft's command-line tool for getting back deleted files: run "winfr" in an
rem administrator command prompt once it's installed. It only comes from the Microsoft Store: this small installer
rem gets it from the Store, so it needs the internet. AOMEI\WinfrGUI gives it a graphical interface.
rem No MajorGeeks backup: its page only links to the Microsoft Store)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\..\_Update-App.ps1" -AppDir "%~dp0Installer" ^
    -Name "Windows File Recovery (Microsoft Store installer)" ^
    -Page "https://apps.microsoft.com/detail/9N26S50LN705" ^
    -Url "https://get.microsoft.com/installer/download/9N26S50LN705" ^
    -SaveAs "Windows File Recovery Installer.exe" -Into "Any"
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
