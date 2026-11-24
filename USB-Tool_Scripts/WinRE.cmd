@echo off
setlocal

title Restart to Advanced Startup (WinRE)

rem Restarts this PC into Advanced Startup (the Windows Recovery Environment: Startup Settings / Safe Mode,
rem System Restore, Command Prompt, UEFI settings, ...)
rem shutdown /o needs admin, so this asks for it first

rem check if already elevated
rem (fltmc only succeeds as administrator; unlike NET FILE it doesn't depend on the Server service, which
rem  isn't running in WinPE or when it's been stopped)
fltmc >nul 2>&1
if not errorlevel 1 goto gotPrivileges

rem the relaunched copy is marked with /elevated: if it still isn't elevated, stop instead of asking again
if /i "%~1" == "/elevated" (
	echo Still not running as administrator after relaunching, so the PC wasn't restarted.
	echo Try right-clicking %~nx0 and choosing "Run as administrator".
	pause
	exit /b 1
)

rem not elevated, relaunch as admin
rem (the path reaches PowerShell in a variable, so spaces, ' & ( ! in it are kept; cmd.exe is started itself,
rem  with the whole command in an extra pair of quotes, as Windows' own Run as administrator for scripts loses
rem  the quotes around a path with & in it)
set "selfPath=%~f0"
powershell -NoProfile -Command "$q = [char]34; $line = '/d /c ' + $q + $q + $env:selfPath + $q + ' /elevated' + $q; try { Start-Process -FilePath ($env:SystemRoot + '\System32\cmd.exe') -ArgumentList $line -Verb RunAs -ErrorAction Stop } catch { exit 1 }"
if errorlevel 1 (
	echo Couldn't start it as administrator ^(was the UAC prompt declined?^), so the PC wasn't restarted.
	pause
	exit /b 1
)
exit /b

:gotPrivileges
shutdown -r -o -f -t 00
if errorlevel 1 (
	echo:
	echo Couldn't restart into Advanced Startup ^(shutdown's exit code: %errorlevel%^).
	echo Windows' recovery environment may be turned off on this PC ^(check with: reagentc /info^).
	pause
	exit /b 1
)
exit /b
