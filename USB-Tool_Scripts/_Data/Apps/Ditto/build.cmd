@echo off

title Build Ditto

rem Builds Ditto from source into this app's Built folder (next to the official download, which update.cmd
rem keeps in Installer / Portable, and which run.cmd starts). Needs: Visual Studio 2022 with the C++ tools and MFC, NuGet (downloaded)
rem See build.ps1 for the details and options, eg. build.cmd -Version x.y.z, -KeepWork or -WorkDir D:\Build

rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
rem /nopause (as Update-Tool.cmd passes to update.cmd) skips the pause at the end, and isn't passed on to build.ps1
set "args=%*"
set "pauseAtEnd=1"
if defined args (
	call set "args=%%args:/nopause=%%"
	echo(%* | "%SystemRoot%\System32\find.exe" /i "/nopause" >nul && set "pauseAtEnd="
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0build.ps1" %args%
set "result=%errorlevel%"

echo:
if defined pauseAtEnd pause
exit /b %result%
