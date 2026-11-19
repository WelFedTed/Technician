@echo off

title Updating Backblaze Computer Backup

rem Updates this app with the shared helper _Data\Apps\_Update-App.ps1 (see that file for the options)
rem Run it on its own, or let Update-Tool.cmd run it for every app
rem Each kind of download has its own folder here: Installer (install.cmd), Portable (run.cmd), CLI (cli.cmd)

rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
set "result=0"
set "resultRank=0"

rem Installer (the backup client, for 64-bit Windows 10 or later; the link on Backblaze's update page,
rem www.backblaze.com/status/update, which always gives the newest version)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0Installer" ^
    -Name "Backblaze Computer Backup (installer)" ^
    -Url "https://secure.backblaze.com/win32/install_backblaze.exe" -Into "x64" ^
    -Clean
call :result

rem Portable (the Standalone Restore App, bzrestore.exe: restores a backup's files after signing in, without
rem installing the backup client, eg. on a new PC)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0Portable" ^
    -Name "Backblaze Restore (portable)" ^
    -Url "https://f000.backblazeb2.com/file/b2-computer-backup-public/windows/standalone-restore/backblaze_restore.zip" ^
    -Extract -Into "x64" ^
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