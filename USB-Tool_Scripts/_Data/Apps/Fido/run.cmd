@echo off
setlocal enableextensions disabledelayedexpansion

title Fido

rem Runs Fido, Rufus's script that downloads Windows ISOs straight from Microsoft (so it needs the internet)
rem With no arguments it opens a small window to choose the version, edition, language and architecture;
rem with arguments it runs from the command line, eg. "run.cmd -Win 11 -Rel Latest -Ed Pro -Lang English -GetUrl"
rem (-GetUrl only prints the download link). It doesn't need admin rights.

set "script=%~dp0Portable\Any\Fido.ps1"
if not exist "%script%" set "script=%~dp0Portable\x86\Fido.ps1"
if not exist "%script%" set "script=%~dp0Portable\Fido.ps1"
if not exist "%script%" (
	echo Couldn't find Fido.ps1 in "%~dp0Portable"
	echo Run Update-Tool.cmd to download it, or check the app's folder.
	pause
	exit /b 1
)

rem (from this folder, so a downloaded ISO doesn't land in System32)
cd /d "%USERPROFILE%\Downloads" 2>nul || cd /d "%USERPROFILE%"
powershell -NoProfile -ExecutionPolicy Bypass -File "%script%" %*
echo:
pause
exit /b