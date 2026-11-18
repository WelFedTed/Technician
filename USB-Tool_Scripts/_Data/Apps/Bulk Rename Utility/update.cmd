@echo off

title Updating Bulk Rename Utility

rem Updates this app with the shared helper _Data\Apps\_Update-App.ps1 (see that file for the options)
rem Run it on its own, or let Update-Tool.cmd run it for every app
rem Each kind of download has its own folder here: Installer (install.cmd), Portable (run.cmd), CLI (cli.cmd)

rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
set "result=0"
set "resultRank=0"

rem Installer
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0Installer" ^
    -Name "Bulk Rename Utility (installer)" ^
    -Page "https://www.bulkrenameutility.co.uk/Download.php" ^
    -Winget "TGRMNSoftware.BulkRenameUtility" -Into "x86" ^
    -Clean ^
    -MajorGeeks "bulk_rename_utility:EXE"
call :result

rem Portable
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0Portable" ^
    -Name "Bulk Rename Utility (portable)" ^
    -Page "https://www.bulkrenameutility.co.uk/Download.php" ^
    -Url "https://www.bulkrenameutility.co.uk/Downloads/BRU_NoInstall.zip" -Inner "64-bit" -Into "x64" ^
    -Url86 "https://www.bulkrenameutility.co.uk/Downloads/BRU_NoInstall.zip" -Inner86 "32-bit" -Into86 "x86" ^
    -Extract -Clean
call :result

rem CLI (Bulk Rename Command, its command-line version, last updated in 2008)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0CLI" ^
    -Name "Bulk Rename Command (BRC)" ^
    -Page "https://www.bulkrenameutility.co.uk/Download.php" ^
    -Url "https://www.bulkrenameutility.co.uk/Downloads/BRC_Unicode_64.zip" -Into "x64" ^
    -Url86 "https://www.bulkrenameutility.co.uk/Downloads/BRC_Unicode_32.zip" -Into86 "x86" ^
    -Extract -Flatten -Clean
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
