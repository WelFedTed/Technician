@echo off

title Updating Microsoft Defender definitions

rem Updates this app with the shared helper _Data\Apps\_Update-App.ps1 (see that file for the options)
rem Run it on its own, or let Update-Tool.cmd run it for every app
rem Each kind of download has its own folder here: Installer (install.cmd), Portable (run.cmd), CLI (cli.cmd)

rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
set "result=0"
set "resultRank=0"

rem Installer (Microsoft Defender Antivirus' definition update package, mpam-fe.exe, for updating Defender on a
rem PC without internet or whose Windows Update is broken: install.cmd runs it for this PC's kind of Windows.
rem From Microsoft's own links, about 210 MB each; Microsoft publishes new definitions several times a day)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\..\_Update-App.ps1" -AppDir "%~dp0Installer" ^
    -Name "Microsoft Defender definitions" ^
    -Page "https://www.microsoft.com/en-us/wdsi/defenderupdates" ^
    -Url "https://go.microsoft.com/fwlink/?LinkID=121721&arch=x64" -SaveAs "mpam-fe.exe" -Into "x64" ^
    -Url86 "https://go.microsoft.com/fwlink/?LinkID=121721&arch=x86" -SaveAs86 "mpam-fe.exe" -Into86 "x86" ^
    -UrlArm "https://go.microsoft.com/fwlink/?LinkID=121721&arch=arm64" -SaveAsArm "mpam-fe.exe" -IntoArm "ARM64" ^
    -Clean ^
    -MajorGeeks "windows_defender_definition_updates:64-Bit 11, 10 & 8.1" -MajorGeeks86 "windows_defender_definition_updates:32-Bit 11, 10 & 8.1"
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