@echo off

title Install Riot Client

rem Riot doesn't offer the Riot Client on its own: each game's installer installs it along with the game.
rem update.cmd keeps two in Installer\x64: League of Legends (Oceania server) and VALORANT (Asia-Pacific server).
rem install.cmd 1 or install.cmd 2 picks one without asking.

set "folder=%~dp0Installer\x64"
set "pick=%~1"
if not defined pick (
	echo Install the Riot Client with:
	echo   1. League of Legends ^(Oceania server^)
	echo   2. VALORANT ^(Asia-Pacific server^)
	choice /c 12 /n /m "Press 1 or 2: "
	if errorlevel 2 ( set "pick=2" ) else ( set "pick=1" )
)
if "%pick%" == "2" ( set "file=%folder%\live.live.ap.exe" ) else ( set "file=%folder%\live.oc1.exe" )
if not exist "%file%" (
	echo Couldn't find "%file%"
	echo Run Update-Tool.cmd to download it, or check the app's folder.
	pause
	exit /b 1
)
echo Starting the installer...
start "" "%file%"
exit /b
