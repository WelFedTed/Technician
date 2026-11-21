@echo off

title Updating Belarc Advisor

rem Updates this app with the shared helper _Data\Apps\_Update-App.ps1 (see that file for the options)
rem Run it on its own, or let Update-Tool.cmd run it for every app
rem Each kind of download has its own folder here: Installer (install.cmd), Portable (run.cmd), CLI (cli.cmd)

rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
set "result=0"
set "resultRank=0"

rem Installer (Belarc Advisor, Belarc's free PC audit tool: it lists the PC's hardware, software, licences, missing
rem updates and security settings, and shows them as a report in the web browser. From Belarc's own download link,
rem which always gives the latest release; its exe carries the app's version. It's a 32-bit setup that asks for
rem admin rights itself, so it's kept in x86. The MajorGeeks backup is MajorGeeks' own copy, as its EXE button
rem just links to Belarc's same download)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0Installer" ^
    -Name "Belarc Advisor" ^
    -Page "https://www.belarc.com/products/belarc-advisor/download" ^
    -Url "https://downloads.belarc.com/advisor/advisorinstaller.exe" -Into "x86" ^
    -Clean ^
    -MajorGeeks "belarc_advisor"
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