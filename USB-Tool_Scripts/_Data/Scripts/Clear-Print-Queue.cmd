@echo off
setlocal
title COPS - Clearing Print Queue

rem check if elevated
rem (fltmc only succeeds as administrator; unlike NET FILE it doesn't depend on the Server service, which
rem  isn't running in WinPE or when it's been stopped, and made the elevated copy relaunch itself over and over)
fltmc >nul 2>&1
if not errorlevel 1 goto gotPrivileges

rem the relaunched copy is marked with /elevated: if it still isn't elevated, stop instead of asking again
if /i "%~1" == "/elevated" (
	echo Still not running as administrator after relaunching, so the print queue wasn't cleared.
	echo Try right-clicking the script and choosing "Run as administrator".
	pause
	exit /b 1
)

:getPrivileges
rem not elevated, relaunch as admin
rem (the path reaches PowerShell in a variable, so spaces, ' & ( ! in it are kept; cmd.exe is started itself,
rem  with the whole command in an extra pair of quotes, as Windows' own Run as administrator for scripts loses
rem  the quotes around a path with & in it)
set "selfPath=%~f0"
powershell -NoProfile -Command "$q = [char]34; $line = '/d /c ' + $q + $q + $env:selfPath + $q + ' /elevated' + $q; try { Start-Process -FilePath ($env:SystemRoot + '\System32\cmd.exe') -ArgumentList $line -Verb RunAs -ErrorAction Stop } catch { exit 1 }"
if errorlevel 1 (
	echo Couldn't start it as administrator ^(was the UAC prompt declined?^), so the print queue wasn't cleared.
	pause
	exit /b 1
)
exit /b

:gotPrivileges

echo Stopping print spooler service...
net stop spooler
echo Clearing print queue...
del %systemroot%\System32\spool\printers\* /Q
echo:
net start spooler

echo:
echo Print queue cleared successfully.
echo:
pause
exit /b
