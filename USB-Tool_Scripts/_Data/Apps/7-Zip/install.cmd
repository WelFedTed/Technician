@echo off
setlocal enabledelayedexpansion

title Install 7-Zip

set "application=7z*.exe"
set "arguments="
set "folder=Installer"

set "elevate=0"
set "runHere=0"
set "openAfter="
set "openPrompt=0"
set "runAtStart=0"


rem Notes
rem ----------------------------------------------------------------------------------------------------
	rem Each app folder in _Data\Apps has up to three scripts made from this template, one for each kind of
	rem download the app has (see _Data\Apps\_Update-App.ps1):
		rem install.cmd: starts the installer in the app's Installer folder
		rem run.cmd:     starts the portable app in its Portable folder (runs without installing)
		rem cli.cmd:     opens a command prompt with the app's command-line tools (CLI folder) on the PATH
	rem Each one picks the right build (x64 / x86 / ARM64) for this PC. The launchers in the root of the USB
	rem tool just call these scripts.
	rem Settings:
		rem application: the file to run, eg. MyApp.exe; can include a subfolder (eg. "bin\MyApp.exe")
			rem and wildcards for files whose names include the version (eg. "MyApp-*.exe");
			rem list several names with ; to try each in turn (eg. "MyAppPortable.exe;MyAppPortableLegacy32bit.exe")
		rem arguments: anything to pass to the application (eg. "-c 10.0.0.1")
		rem folder: Installer, Portable or CLI (the app folder's subfolder to look in)
		rem elevate: 1 to run as admin, else 0
		rem runHere: 1 to run in this window and pause afterwards (console tools and scripts), else 0
		rem openAfter: a folder to open in Explorer after starting the application (optional)
		rem openPrompt: 1 to open a command prompt in the application's folder, with it on the PATH (cli.cmd)
		rem runAtStart: with openPrompt, 1 to run the application (with arguments) as the prompt opens
		rem Arguments given to this script are passed to the application (with openPrompt, they're run in
		rem the prompt, eg. "cli.cmd -s" runs "iperf3.exe -s")
	rem Build folders, inside the Installer / Portable / CLI folder:
		rem x64 / x86 / ARM64: one build each; x86 also holds installers and scripts that run anywhere
		rem x86_x64 / x86_x64_ARM64: one download holding several builds that share files, named eg.
			rem myApp.exe + myApp64.exe, myApp.x86.exe + myApp.x64.exe, or myApp_x32.exe + myApp_x64.exe + myApp_arm64.exe,
			rem or with each build in an x64 / ARM64 subfolder (eg. 7-Zip Extra's x64\7za.exe)
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
	set "base=%~dp0%folder%"

	rem this PC's architecture (also when this window is a 32-bit or emulated one)
	set "arch=x86"
	if /i "%PROCESSOR_ARCHITECTURE%" == "AMD64" set "arch=x64"
	if /i "%PROCESSOR_ARCHITEW6432%" == "AMD64" set "arch=x64"
	if /i "%PROCESSOR_ARCHITECTURE%" == "ARM64" set "arch=ARM64"
	if /i "%PROCESSOR_ARCHITEW6432%" == "ARM64" set "arch=ARM64"
	echo %arch% Windows detected

	rem look in the best places first: ARM64 Windows also runs x64 and x86 builds, and x64 Windows runs x86;
	rem the type folder itself is last so files saved there by hand still work
	rem application can list several names separated by ; (eg. when the 32-bit build's launcher has
	rem another name); each is tried in turn. for /f splits them without expanding wildcards.
	set "found="
	set "names=%application%"
	:nextName
	if defined found goto doneSearching
	if not defined names goto doneSearching
	for /f "tokens=1* delims=;" %%a in ("!names!") do (
		set "A=%%a"
		set "names=%%b"
	)
	set "N=!A:~0,-4!"
	set "E=!A:~-4!"
	if "%arch%" == "ARM64" call :findArm64
	if "%arch%" == "ARM64" call :find64
	if "%arch%" == "x64" call :find64
	call :find86
	if not "%arch%" == "x86" call :findIn "%N%_x64%E%" "%N%64%E%"
	call :findIn "%N%_x86%E%" "%N%_x32%E%" "%A%"
	goto nextName
	:doneSearching

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
	set "runDir=%runDir:~0,-1%"
	cd /d "%runDir%"

	if "%openPrompt%" == "1" goto openPrompt

	echo Starting %runFile%...
	if not "%~1" == "" set "arguments=%*"
	if "%runHere%" == "1" (
		call "%runFile%" %arguments%
		echo:
		pause
	) else (
		start "" "%runFile%" %arguments%
	)

	if defined openAfter explorer.exe "%openAfter%"
	exit /b

	:openPrompt
	rem a command prompt in the tool's folder, with that folder first on the PATH so its tools run from anywhere
	rem (a build in a subfolder of a combined download, eg. x86_x64_ARM64\x64\7za.exe, also gets the tools
	rem next to that subfolder, eg. x86_x64_ARM64\7zr.exe)
	set "extraDir="
	for %%P in ("%runDir%\..") do (
		set "parentDir=%%~fP"
		set "parentName=%%~nxP"
	)
	if /i "!parentName:~0,7!" == "x86_x64" set "extraDir=!parentDir!"
	if defined extraDir ( set "PATH=%runDir%;%extraDir%;%PATH%" ) else ( set "PATH=%runDir%;%PATH%" )
	echo:
	echo Command-line tools:
	for %%T in ("%runDir%\*.exe" "%runDir%\*.cmd" "%runDir%\*.bat") do echo   %%~nxT
	rem (tools next to the subfolder that this build doesn't have its own copy of)
	if defined extraDir for %%T in ("%extraDir%\*.exe" "%extraDir%\*.cmd" "%extraDir%\*.bat") do if not exist "%runDir%\%%~nxT" echo   %%~nxT
	echo:
	echo Type the tool's name to use it (eg. %runFile% --help), or "exit" to close this prompt.
	echo:
	if not "%~1" == "" (
		cmd /k ""%runFile%" %*"
		exit /b
	)
	if "%runAtStart%" == "1" (
		cmd /k ""%runFile%" %arguments%"
		exit /b
	)
	cmd /k
	exit /b


rem Search Helpers
rem ----------------------------------------------------------------------------------------------------
	rem names of each build, as different downloads name them
	:findArm64
	call :findIn "ARM64\%A%" "ARM64\%N%ARM64%E%" "ARM64\%N%_arm64%E%" "x86_x64_ARM64\%N%_arm64%E%" "x86_x64_ARM64\%N%ARM64%E%" "x86_x64_ARM64\%N%64a%E%" "x86_x64_ARM64\ARM64\%A%"
	exit /b

	:find64
	call :findIn "x64\%A%" "x64\%N%_x64%E%" "x64\%N%64%E%" "x86_x64_ARM64\%N%_x64%E%" "x86_x64_ARM64\%N%64%E%" "x86_x64_ARM64\x64\%A%" "x86_x64\%N%_x64%E%" "x86_x64\%N%64%E%" "x86_x64\%N%.x64%E%" "x86_x64\x64\%A%"
	exit /b

	:find86
	call :findIn "x86\%A%" "x86_x64\%N%_x86%E%" "x86_x64\%N%_x32%E%" "x86_x64\%N%32%E%" "x86_x64\%N%.x86%E%" "x86_x64\%A%" "x86_x64_ARM64\%N%_x86%E%" "x86_x64_ARM64\%N%_x32%E%" "x86_x64_ARM64\%N%32%E%" "x86_x64_ARM64\%A%"
	exit /b

	rem tries each path in turn; paths may contain wildcards (eg. MyApp-*.exe), so matching files are listed
	rem here rather than in the caller (a for loop there would look for them in the current folder instead)
	:findIn
	if defined found exit /b
	if "%~1" == "" exit /b
	for %%F in ("%base%\%~1") do if not defined found if exist "%%~fF" set "found=%%~fF"
	shift
	goto findIn
