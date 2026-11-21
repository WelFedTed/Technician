@echo off

title Updating Personal Backup

rem Updates this app with the shared helper _Data\Apps\_Update-App.ps1 (see that file for the options)
rem Run it on its own, or let Update-Tool.cmd run it for every app
rem Each kind of download has its own folder here: Installer (install.cmd), Portable (run.cmd), CLI (cli.cmd)

rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
set "result=0"
set "resultRank=0"

rem Installer (Personal Backup, J. Rathlev's freeware backup tool: the 64-bit and 32-bit setups from the author's
rem download page, whose links carry the version, eg. pb-setup-x64-6.4.1500.exe. They aren't code-signed: the
rem author signs them with OpenPGP instead, in the .sig files next to them on the page)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0Installer" ^
    -Name "Personal Backup (installer)" ^
    -Page "https://personal-backup.rathlev-home.de/download-e.html" ^
    -Link "download/pb-setup-x64-[\d.]+\.exe" -Into "x64" ^
    -Link86 "download/pb-setup-[\d.]+\.exe" -Into86 "x86" ^
    -Clean ^
    -MajorGeeks "personal_backup:64-Bit EXE" ^
    -MajorGeeks86 "personal_backup:32-Bit EXE"
call :result

rem Portable (the author's zips "for update or portable version", from the same page. Their names only carry part
rem of the version and can't be compared (6.2 was pb-update-6.zip, 6.4 is pb-update-64.zip), so the links take
rem the first zip on the page, the newest, and the version is read from PersBackup.exe. run.cmd starts it with
rem /portable, which keeps its settings, backup tasks and logs next to it on the USB; an update replaces them)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0Portable" ^
    -Name "Personal Backup (portable)" ^
    -Page "https://personal-backup.rathlev-home.de/download-e.html" ^
    -Link "download/pb-update-x64-\d+\.zip(?<!download/pb-update-x64-\d+\.zip[\s\S]+download/pb-update-x64-\d+\.zip)" -Into "x64" ^
    -Link86 "download/pb-update-\d+\.zip(?<!download/pb-update-\d+\.zip[\s\S]+download/pb-update-\d+\.zip)" -Into86 "x86" ^
    -Extract -Flatten -Clean ^
    -VersionFrom "x64\PersBackup.exe" ^
    -MajorGeeks "personal_backup:64-Bit Portable" ^
    -MajorGeeks86 "personal_backup:32-Bit Portable"
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
