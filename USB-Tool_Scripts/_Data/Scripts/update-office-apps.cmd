@echo off
setlocal

title Update Office Apps

rem Updates the Click-to-Run Office apps on this PC (Microsoft 365, Office 2016 and later), with Office's own updater
rem (OfficeC2RClient.exe); any Office apps that are open are closed so they can be updated
rem It's in Common Files: the 64-bit one for 64-bit Office, "Program Files (x86)" for 32-bit Office
rem (%CommonProgramW6432% is the 64-bit one also when this runs in a 32-bit window, where %CommonProgramFiles% is the x86 one)

set "c2r="
for %%D in ("%CommonProgramFiles%" "%CommonProgramW6432%" "%CommonProgramFiles(x86)%") do (
	if not defined c2r if not "%%~D" == "" if exist "%%~D\microsoft shared\ClickToRun\OfficeC2RClient.exe" set "c2r=%%~D\microsoft shared\ClickToRun\OfficeC2RClient.exe"
)
if not defined c2r (
	echo Couldn't find Office's updater ^(OfficeC2RClient.exe in "Common Files\microsoft shared\ClickToRun"^),
	echo so this PC doesn't seem to have a Click-to-Run version of Office ^(Microsoft 365, Office 2016 or later^).
	echo Office installed from an MSI ^(eg. Office 2010 or 2013^) gets its updates from Windows Update instead.
	echo:
	pause
	exit /b 1
)

echo Starting Office's updater ^(any open Office apps will be closed^)...
echo   %c2r%
"%c2r%" /update user forceappshutdown=true
if errorlevel 1 (
	echo:
	echo Office's updater couldn't be started ^(exit code %errorlevel%^).
	pause
	exit /b 1
)
echo:
echo Office's updater is running: it shows its own window while it checks for and installs updates.
pause
exit /b
