@echo off
setlocal enabledelayedexpansion

title File-Drop

set "directory=_Data\Apps\File Drop"
set "application=file-drop.exe"
set "arguments="

set "elevate=0"
set "runHere=0"
set "openAfter="


rem Notes
rem ----------------------------------------------------------------------------------------------------
	rem Copy this template file, rename it (eg. MyApp.cmd), and update the settings above:
		rem title: the application's name (eg. "My Application Deluxe")
		rem directory: the application's folder without the drive letter (eg. "_Data\Apps\MyApp")
		rem application: the file to run (eg. MyApp.exe); can include a subfolder (eg. "bin\MyApp.exe")
		rem arguments: anything to pass to the application (eg. "-c 10.0.0.1")
		rem elevate: 1 to run as admin, else 0
		rem runHere: 1 to run in this window and pause afterwards (console tools and scripts), else 0
		rem openAfter: a folder to open in Explorer after starting the application (optional)
	rem These batch files are designed to be run from the root directory (eg. Z:\MyApp.cmd)
		rem The batch file must be run from the drive where the application is located
		rem The batch files work regardless of drive letter (unlike shortcuts)
		rem If you know the drive letter of your drive, launch apps quickly with using Run (eg. Z:\MyApp)
	rem Apps keep their builds in x64 and x86 subfolders (see _Data\Apps\_Update-App.ps1):
		rem x64: builds that only run on 64-bit Windows
		rem x86: anything that runs on 32-bit Windows (also used on 64-bit when there's no x64 build)
		rem Combined downloads may hold both builds in x86, eg. myApp_x64.exe + myApp_x32.exe, or myApp64.exe + myApp.exe
		rem so set application to the plain name (myApp.exe) and the right build is picked automatically
	rem Delayed Expansion is used to enable setting variables within if statements
	rem exit /b is being used to exit this script without closing the shell that called it


rem Check Elevated
rem ----------------------------------------------------------------------------------------------------
	if not "%elevate%" == "1" goto skipCheckElevated

	rem check if already elevated
	NET FILE 1>NUL 2>NUL
	if '%errorlevel%' == '0' ( goto gotPrivileges ) else ( goto getPrivileges )

	:getPrivileges
	rem not elevated, relaunch as admin
	powershell -command start-process -file '%~f0' -verb runas
	exit /b

	:gotPrivileges
	rem is elevated, continue script
	echo Running as Administrator

	:skipCheckElevated


rem Find Application
rem ----------------------------------------------------------------------------------------------------
	set "base=%~d0\%directory%"
	set "name=%application:~0,-4%"
	set "ext=%application:~-4%"

	rem 64-bit Windows (including 32-bit cmd on 64-bit Windows, and ARM64)
	set "is64=0"
	if /i "%PROCESSOR_ARCHITECTURE%" == "AMD64" set "is64=1"
	if /i "%PROCESSOR_ARCHITECTURE%" == "ARM64" set "is64=1"
	if defined PROCESSOR_ARCHITEW6432 set "is64=1"

	rem places to look, best first; the app folder itself is last so the old layout still works
	if "%is64%" == "1" (
		echo 64-bit Windows detected
		set "candidates="x64\%application%" "x64\%name%_x64%ext%" "x64\%name%64%ext%" "x86\%name%_x64%ext%" "x86\%name%64%ext%" "x86\%application%" "%name%_x64%ext%" "%name%64%ext%" "%application%""
	) else (
		echo 32-bit Windows detected
		set "candidates="x86\%application%" "x86\%name%_x86%ext%" "x86\%name%_x32%ext%" "%name%_x86%ext%" "%name%_x32%ext%" "%application%""
	)

	set "found="
	for %%P in (!candidates!) do (
		if not defined found if exist "%base%\%%~P" set "found=%base%\%%~P"
	)
	if not defined found if "%is64%" == "0" if exist "%base%\x64\%application%" (
		echo "%application%" only has a 64-bit build, so it can't run on this 32-bit PC.
		pause
		exit /b 1
	)
	if not defined found (
		echo Couldn't find "%application%" in "%base%"
		echo Run Update-Tool.cmd to download it, or check the app's folder.
		pause
		exit /b 1
	)


rem Run Application/Script
rem ----------------------------------------------------------------------------------------------------
	rem if you need extra functionality add it to the script below or replace with with your own code
	for %%F in ("%found%") do (
		set "runDir=%%~dpF"
		set "runFile=%%~nxF"
	)
	cd /d "%runDir%"
	echo Starting %runFile%...

	if "%runHere%" == "1" (
		call "%runFile%" %arguments%
		echo:
		pause
	) else (
		start "" "%runFile%" %arguments%
	)

	if defined openAfter explorer.exe "%openAfter%"
	exit /b
