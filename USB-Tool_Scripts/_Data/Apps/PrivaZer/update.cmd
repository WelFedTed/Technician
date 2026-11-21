@echo off

title Updating PrivaZer

rem Updates this app with the shared helper _Data\Apps\_Update-App.ps1 (see that file for the options)
rem Run it on its own, or let Update-Tool.cmd run it for every app
rem Each kind of download has its own folder here: Installer (install.cmd), Portable (run.cmd), CLI (cli.cmd)

rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
set "result=0"
set "resultRank=0"

rem Installer (PrivaZer, Goversoft's privacy cleaner, from Goversoft's own download link, which always gives the
rem latest release. It's a 32-bit program, so it's kept in x86, and it asks for admin rights itself)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0Installer" ^
    -Name "PrivaZer (installer)" ^
    -Page "https://privazer.com/en/download.php" ^
    -Url "https://privazer.com/PrivaZer_free.exe" -Into "x86" ^
    -Clean ^
    -MajorGeeks "privazer:EXE"
call :result

rem Portable (Goversoft's portable version, from the download page's "Download the portable version" link: one
rem 32-bit exe that runs without installing)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0Portable" ^
    -Name "PrivaZer (portable)" ^
    -Page "https://privazer.com/en/download.php" ^
    -Url "https://privazer.com/PrivaZer.exe" -Into "x86" ^
    -Clean ^
    -MajorGeeks "privazer:Portable"
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
