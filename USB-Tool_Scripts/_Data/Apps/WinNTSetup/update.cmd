@echo off

title Updating WinNTSetup

rem Updates this app with the shared helper _Data\Apps\_Update-App.ps1 (see that file for the options)
rem Run it on its own, or let Update-Tool.cmd run it for every app
rem Each kind of download has its own folder here: Installer (install.cmd), Portable (run.cmd), CLI (cli.cmd)

rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
set "result=0"
set "resultRank=0"

rem Portable (from MajorGeeks' copies of the 64-bit and 32-bit builds: the author's own download is on the MSFN
rem forum, https://msfn.org/board/topic/149612-winntsetup-v54/, which doesn't answer scripts)
rem MajorGeeks' mirror page starts a session that its download link needs, hence -Cookies; the link changes each
rem visit, so each run downloads the .rar files again (about 3 MB), and the same files count as up to date
rem (antivirus apps often flag WinNTSetup, as it changes Windows installs)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0Portable" ^
    -Name "WinNTSetup" ^
    -Page "https://www.majorgeeks.com/mg/getmirror/winntsetup_64_bit,2.html" ^
    -Link "index\.php\?ct=files&action=download&PHPSESSID=\w+" -Into "x64" ^
    -Page86 "https://www.majorgeeks.com/mg/getmirror/winntsetup,2.html" ^
    -Link86 "index\.php\?ct=files&action=download&PHPSESSID=\w+" -Into86 "x86" ^
    -Cookies ^
    -Extract -Clean -Keep "WinNTSetup.ini" ^
    -VersionFrom "x64\WinNTSetup_x64.exe"
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
