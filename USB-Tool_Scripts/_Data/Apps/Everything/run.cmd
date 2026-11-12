@echo off
setlocal enabledelayedexpansion

title Everything

set "application=Everything.exe"
set "arguments="

set "elevate=1"
set "runHere=0"
set "openAfter="


rem Notes
rem ----------------------------------------------------------------------------------------------------
	rem Each app folder in _Data\Apps has a run.cmd made from this template; it starts the right build of
	rem the app for this PC. The launchers in the root of the USB tool just call these run.cmd files.
	rem Settings:
		rem application: the file to run, eg. MyApp.exe; can include a subfolder (eg. "bin\MyApp.exe")
			rem and wildcards for files whose names include the version (eg. "MyApp-*.exe")
		rem arguments: anything to pass to the application (eg. "-c 10.0.0.1")
		rem elevate: 1 to run as admin, else 0
		rem runHere: 1 to run in this window and pause afterwards (console tools and scripts), else 0
		rem openAfter: a folder to open in Explorer after starting the application (optional)
	rem Build folders (see _Data\Apps\_Update-App.ps1):
		rem x64 / x86 / ARM64: one build each; x86 also holds installers and scripts that run anywhere
		rem x86_x64 / x86_x64_ARM64: one download holding several builds that share files, named eg.
			rem myApp.exe + myApp64.exe, or myApp_x32.exe + myApp_x64.exe + myApp_arm64.exe
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
	set "base=%~dp0"
	set "base=%base:~0,-1%"
	set "A=%application%"
	set "N=%application:~0,-4%"
	set "E=%application:~-4%"

	rem this PC's architecture (also when this window is a 32-bit or emulated one)
	set "arch=x86"
	if /i "%PROCESSOR_ARCHITECTURE%" == "AMD64" set "arch=x64"
	if /i "%PROCESSOR_ARCHITEW6432%" == "AMD64" set "arch=x64"
	if /i "%PROCESSOR_ARCHITECTURE%" == "ARM64" set "arch=ARM64"
	if /i "%PROCESSOR_ARCHITEW6432%" == "ARM64" set "arch=ARM64"
	echo %arch% Windows detected

	rem look in the best places first: ARM64 Windows also runs x64 and x86 builds, and x64 Windows runs x86;
	rem the app folder itself is last so the old layout still works
	set "found="
	if "%arch%" == "ARM64" call :findArm64
	if "%arch%" == "ARM64" call :find64
	if "%arch%" == "x64" call :find64
	call :find86
	if not "%arch%" == "x86" call :findIn "%N%_x64%E%" "%N%64%E%"
	call :findIn "%N%_x86%E%" "%N%_x32%E%" "%A%"

	if not defined found if "%arch%" == "x86" if exist "%base%\x64\" (
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


rem Search Helpers
rem ----------------------------------------------------------------------------------------------------
	rem names of each build, as different downloads name them
	:findArm64
	call :findIn "ARM64\%A%" "ARM64\%N%ARM64%E%" "ARM64\%N%_arm64%E%" "x86_x64_ARM64\%N%_arm64%E%" "x86_x64_ARM64\%N%ARM64%E%" "x86_x64_ARM64\%N%64a%E%"
	exit /b

	:find64
	call :findIn "x64\%A%" "x64\%N%_x64%E%" "x64\%N%64%E%" "x86_x64_ARM64\%N%_x64%E%" "x86_x64_ARM64\%N%64%E%" "x86_x64\%N%_x64%E%" "x86_x64\%N%64%E%"
	exit /b

	:find86
	call :findIn "x86\%A%" "x86_x64\%N%_x86%E%" "x86_x64\%N%_x32%E%" "x86_x64\%N%32%E%" "x86_x64\%A%" "x86_x64_ARM64\%N%_x86%E%" "x86_x64_ARM64\%N%_x32%E%" "x86_x64_ARM64\%N%32%E%" "x86_x64_ARM64\%A%"
	exit /b

	rem tries each path in turn; paths may contain wildcards (eg. MyApp-*.exe), so matching files are listed
	rem here rather than in the caller (a for loop there would look for them in the current folder instead)
	:findIn
	if defined found exit /b
	if "%~1" == "" exit /b
	for %%F in ("%base%\%~1") do if not defined found if exist "%%~fF" set "found=%%~fF"
	shift
	goto findIn
