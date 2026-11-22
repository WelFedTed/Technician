@echo off

title Updating Claude Code

rem Updates this app with the shared helper _Data\Apps\_Update-App.ps1 (see that file for the options)
rem Run it on its own, or let Update-Tool.cmd run it for every app
rem Each kind of download has its own folder here: Installer (install.cmd), Portable (run.cmd), CLI (cli.cmd)

rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
set "result=0"
set "resultRank=0"

rem Installer (Claude Code, Anthropic's AI coding assistant for the terminal. Its official install command,
rem irm https://claude.ai/install.ps1 | iex, downloads claude.exe from downloads.claude.ai, checks its SHA256 and
rem runs "claude.exe install", which sets it up for the current user in %USERPROFILE%\.local\bin. install.cmd runs
rem that command first, and this copy of claude.exe (run with "install") only when that doesn't work. The x64 and
rem ARM64 claude.exe come from the same downloads.claude.ai links as winget lists them, which gives the version
rem and each file's SHA256. There's no 32-bit build. No MajorGeeks backup: MajorGeeks has no page for it)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0Installer" ^
    -Name "Claude Code" ^
    -Page "https://code.claude.com/docs/en/setup" ^
    -Winget "Anthropic.ClaudeCode" -Into "x64" -IntoArm "ARM64" ^
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