@echo off

title Updating Tftpd64

rem Updates this app with the shared helper _Data\Apps\_Update-App.ps1 (see that file for the options)
rem Run it on its own, or let Update-Tool.cmd run it for every app
rem Each kind of download has its own folder here: Installer (install.cmd), Portable (run.cmd), CLI (cli.cmd)

rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
set "result=0"
set "resultRank=0"

rem Portable (a TFTP, DHCP, DNS, SNTP and syslog server, eg. for flashing routers and switches: tftpd64.exe for
rem 64-bit Windows, tftpd32.exe for 32-bit. Its settings stay in tftpd32.ini next to it, which is kept on updates.
rem No MajorGeeks backup: it isn't listed there)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0Portable" ^
    -Name "Tftpd64" ^
    -Page "https://github.com/PJO2/tftpd64/releases/latest" ^
    -GitHub "PJO2/tftpd64" -Asset "^tftpd64_portable_v[\d.]+\.zip$" -Into "x64" ^
    -Asset86 "^tftpd32_portable_v[\d.]+\.zip$" -Into86 "x86" ^
    -Extract -Clean -Keep "tftpd32.ini"
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
