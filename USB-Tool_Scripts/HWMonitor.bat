@echo off
setlocal enabledelayedexpansion

title HWMonitor

set "directory=_Data\Apps\CPUID HWMonitor"
set "application=HWMonitor.exe"

set skipCheckElevated=0
set skipCheckArchitecture=0


rem Notes
rem ----------------------------------------------------------------------------------------------------
	rem Copy this template file, rename it (eg. MyApp.bat), and update the placeholder variables:
		rem title: Set this to the title of the application (eg. "My Application Deluxe")
		rem directory: Set this to the application's directory without the driver letter (eg. "Apps\MyApp")
		rem application: Set this to the application's executable filename (eg. MyApp.exe)
		rem skipCheckElevated: Set this to 0 if the application should be run as admin, else set to 1
		rem skipCheckArchitecture: Set this to 0 if the application has x86 + x64 versions, else set to 1
	rem These batch files are designed to be run from the root directory (eg. Z:\MyApp.bat)
		rem The batch file must be run from the drive where the application is located
		rem The batch files work regardless of drive letter (unlike shortcuts)
		rem If you know the drive letter of your drive, launch apps quickly with using Run (eg. Z:\MyApp)
	rem File structure for applications with multiple architectures (x86 + x64):
		rem If you have separate folders for different architectures:
			rem Name the folders "x86" and "x64" respectively
				rem eg. MyApp\x86\myApp.exe + MyApp\x64\myApp.exe
		rem If you have separate executables for different architectures in the same folder:
			rem Append "_x86" or "_x64" to their filenames respectively
				rem eg. MyApp\myApp_x86.exe + MyApp\myApp_x64.exe
	rem Delayed Expanstion is used to enable setting variables within if statements (see Check Architecture)
	rem exit /b is being used to exit this script without closing the shell that called it


rem Check Elevated
rem ----------------------------------------------------------------------------------------------------
	if %skipCheckElevated% == 1 ( goto skipCheckElevated )

	rem check if already elevated
	NET FILE 1>NUL 2>NUL
	if '%errorlevel%' == '0' ( goto gotPrivileges ) else ( goto getPrivileges )

	:getPrivileges
	rem not elevated, relaunch as admin
	powershell -command start-process -file %~f0 -verb runas
	exit /b

	:gotPrivileges
	rem is elevated, continue script
	echo Running as Administrator

	:skipCheckElevated


rem Check Architecture
rem ----------------------------------------------------------------------------------------------------
	if %skipCheckArchitecture% == 1 ( goto skipCheckArchitecture )

	rem check if x86 or x64
	if %PROCESSOR_ARCHITECTURE% == x86 ( if NOT DEFINED PROCESSOR_ARCHITEW6432 goto x86 ) else ( goto x64 )

	:x86
	rem overwrite with x86 variables
	echo 32-Bit Detected
	set architecture=x32
	goto overwrite

	:x64
	rem overwrite with x64 variables
	echo 64-Bit Detected
	set architecture=x64
	goto overwrite

	:overwrite
	if exist "%~d0\%directory%\%architecture%" (
		echo updating target directory...
		set "directory=%directory%\%architecture%"
	) else (
		echo updating target executable...
		set "applicationName=%application:~0,-4%"
		set "applicationExtenstion=%application:~-3%"
		set "application=!applicationName!_%architecture%.!applicationExtenstion!"
	)
	goto script

	:skipCheckArchitecture


rem Run Application/Script
rem ----------------------------------------------------------------------------------------------------
	:script
	rem if you need extra functionality add it to the script below or replace with with your own code
	cd /d %~d0
	cd %directory%
	start %application%
	exit /b