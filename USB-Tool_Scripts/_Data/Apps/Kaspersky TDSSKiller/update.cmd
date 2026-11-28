@echo off

title Updating Kaspersky TDSSKiller

rem Updates this app with the shared helper _Data\Apps\_Update-App.ps1 (see that file for the options)
rem Run it on its own, or let Update-Tool.cmd run it for every app
rem Each kind of download has its own folder here: Installer (install.cmd), Portable (run.cmd), CLI (cli.cmd)

rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
set "result=0"
set "resultRank=0"

rem Kaspersky TDSSKiller (a rootkit and bootkit scanner) is discontinued: 3.1.0.28 is its final version, and
rem Kaspersky's page and link (media.kaspersky.com/utilities/VirusUtilities/EN/tdsskiller.exe) have given 404
rem since April 2026. So it comes from the Internet Archive's copy of that link (saved 6 June 2023, the same file it
rem saved from Nov 2019 on). No MajorGeeks backup: its download button only leads to Kaspersky's dead link.
rem Kaspersky published no hash, so the SHA256 is pinned to the copy checked on 28 Nov 2026: Kaspersky Lab's
rem Authenticode signature is valid (DigiCert, timestamped), its version is 3.1.0.28, and Defender finds nothing.
rem The download must have that SHA256, or it isn't used (-Hash).
rem Kaspersky Virus Removal Tool (KVRT), also on the USB, is still updated and also finds rootkits.

rem Portable (32-bit, runs on every PC; it asks for admin rights itself)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0Portable" ^
    -Name "Kaspersky TDSSKiller" ^
    -Page "https://www.majorgeeks.com/files/details/kaspersky_tdsskiller.html" ^
    -Url "https://web.archive.org/web/20230606053547id_/https://media.kaspersky.com/utilities/VirusUtilities/EN/tdsskiller.exe" ^
    -SaveAs "tdsskiller.exe" -Into "x86" ^
    -Hash "2D823C8B6076E932D696E8CB8A2C5C5DF6D392526CBA8E39B64C43635F683009" ^
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