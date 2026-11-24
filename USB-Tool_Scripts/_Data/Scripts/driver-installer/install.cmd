@echo off
setlocal

title Install Drivers

rem Installs every driver (.inf file) in this folder and its subfolders, with Install-WindowsDriversFromFolder.ps1
rem Put the drivers in this folder first (eg. unpacked from the PC maker's driver pack), then run this; it asks to
rem run as admin, as installing drivers needs it

rem check if already elevated
rem (fltmc only succeeds as administrator; unlike net session it doesn't depend on the Server service, which
rem  isn't running in WinPE or when it's been stopped)
echo Checking if you have Administrator permissions...
fltmc >nul 2>&1
if not errorlevel 1 goto gotPrivileges

rem the relaunched copy is marked with /elevated: if it still isn't elevated, stop instead of asking again
if /i "%~1" == "/elevated" (
	echo Still not running as administrator after relaunching, so no drivers were installed.
	echo Try right-clicking %~nx0 and choosing "Run as administrator".
	pause
	exit /b 1
)

rem not elevated, relaunch as admin
rem (the path reaches PowerShell in a variable, so spaces, ' & ( ! in it are kept; cmd.exe is started itself,
rem  with the whole command in an extra pair of quotes, as Windows' own Run as administrator for scripts loses
rem  the quotes around a path with & in it)
echo Asking for Administrator permissions...
set "selfPath=%~f0"
powershell -NoProfile -Command "$q = [char]34; $line = '/d /c ' + $q + $q + $env:selfPath + $q + ' /elevated' + $q; try { Start-Process -FilePath ($env:SystemRoot + '\System32\cmd.exe') -ArgumentList $line -Verb RunAs -ErrorAction Stop } catch { exit 1 }"
if errorlevel 1 (
	echo Couldn't start it as administrator ^(was the UAC prompt declined?^), so no drivers were installed.
	pause
	exit /b 1
)
exit /b

:gotPrivileges
echo You have Administrator permissions, installing drivers...
echo:
rem (the folder is given as "...\." so its trailing \ doesn't escape the closing quote)
powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%~dp0Install-WindowsDriversFromFolder.ps1" "%~dp0."
if errorlevel 1 (
	echo:
	echo Installing the drivers failed ^(exit code %errorlevel%^).
	pause
	exit /b 1
)
echo:
echo Installation Complete
pause
exit /b
