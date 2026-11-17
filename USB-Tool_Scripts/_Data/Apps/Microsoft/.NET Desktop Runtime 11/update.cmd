@echo off

title Updating .NET Desktop Runtime 11

rem Updates this app with the shared helper _Data\Apps\_Update-App.ps1 (see that file for the options)
rem Run it on its own, or let Update-Tool.cmd run it for every app
rem Each kind of download has its own folder here: Installer (install.cmd), Portable (run.cmd), CLI (cli.cmd)

rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
set "result=0"
set "resultRank=0"

rem Installer (the current release, supported until November 2028; it includes the .NET Runtime)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\..\_Update-App.ps1" -AppDir "%~dp0Installer" ^
    -Name ".NET Desktop Runtime 11" ^
    -Page "https://dotnet.microsoft.com/download/dotnet/11.0" ^
    -Url "https://aka.ms/dotnet/11.0/windowsdesktop-runtime-win-x64.exe" -Into "x64" ^
    -Url86 "https://aka.ms/dotnet/11.0/windowsdesktop-runtime-win-x86.exe" -Into86 "x86" ^
    -UrlArm "https://aka.ms/dotnet/11.0/windowsdesktop-runtime-win-arm64.exe" -IntoArm "ARM64" ^
    -VersionFromUrl -Clean
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
