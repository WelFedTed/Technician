@echo off

title Updating Adlice RogueKiller

rem Updates this app with the shared helper _Data\Apps\_Update-App.ps1 (see that file for the options)
rem Run it on its own, or let Update-Tool.cmd run it for every app
rem Each kind of download has its own folder here: Installer (install.cmd), Portable (run.cmd), CLI (cli.cmd)

rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
set "result=0"
set "resultRank=0"

rem Installer (anti-malware scanner; the free edition is for personal use; the Windows 10+ setup in x64, the Windows 7+ one in x86)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\..\_Update-App.ps1" -AppDir "%~dp0Installer" ^
    -Name "Adlice RogueKiller (installer)" ^
    -Page "https://www.adlice.com/roguekiller/" ^
    -Url "https://download.adlice.com/api?action=download&app=roguekiller&type=setup&os=win10" -SaveAs "RogueKiller_setup_win10.exe" -Into "x64" ^
    -Url86 "https://download.adlice.com/api?action=download&app=roguekiller&type=setup&os=win7" -SaveAs86 "RogueKiller_setup.exe" -Into86 "x86" ^
    -Clean
call :result

rem Portable (the Windows 10+ 64-bit, 32-bit and ARM64 builds)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\..\_Update-App.ps1" -AppDir "%~dp0Portable" ^
    -Name "Adlice RogueKiller (portable)" ^
    -Page "https://www.adlice.com/roguekiller/" ^
    -Url "https://download.adlice.com/api?action=download&app=roguekiller&type=x64&os=win10" -SaveAs "RogueKiller.exe" -Into "x64" ^
    -Url86 "https://download.adlice.com/api?action=download&app=roguekiller&type=x86" -SaveAs86 "RogueKiller.exe" -Into86 "x86" ^
    -UrlArm "https://download.adlice.com/api?action=download&app=roguekiller&type=arm64" -SaveAsArm "RogueKiller.exe" -IntoArm "ARM64" ^
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
