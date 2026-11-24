@echo off
setlocal

title Export Drivers

rem Exports this PC's third-party drivers (the ones Windows doesn't come with) with Export-WindowsDriversToFolder.ps1,
rem to C:\Drivers\_Backup_<date>, so they can be put back later (eg. with driver-installer\install.cmd)
rem It asks to run as admin, as exporting drivers needs it

rem check if already elevated
rem (fltmc only succeeds as administrator; unlike net session it doesn't depend on the Server service, which
rem  isn't running in WinPE or when it's been stopped)
echo Checking if you have Administrator permissions...
fltmc >nul 2>&1
if not errorlevel 1 goto gotPrivileges

rem the relaunched copy is marked with /elevated: if it still isn't elevated, stop instead of asking again
if /i "%~1" == "/elevated" (
	echo Still not running as administrator after relaunching, so no drivers were exported.
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
	echo Couldn't start it as administrator ^(was the UAC prompt declined?^), so no drivers were exported.
	pause
	exit /b 1
)
exit /b

:gotPrivileges
echo You have Administrator permissions, exporting drivers...
echo:
powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%~dp0Export-WindowsDriversToFolder.ps1"
if errorlevel 1 (
	echo:
	echo Exporting the drivers failed ^(exit code %errorlevel%^).
	pause
	exit /b 1
)
echo:
echo Export Complete
pause
exit /b
