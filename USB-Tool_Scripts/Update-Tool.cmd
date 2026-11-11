@echo off
setlocal EnableExtensions EnableDelayedExpansion

title USB Tool Updater

rem Notes
rem ----------------------------------------------------------------------------------------------------
	rem Run from the root of the USB tool (eg. Z:\Update-Tool.cmd)
	rem   1. Scripts: downloads the latest USB-Tool_Scripts folder from GitHub and copies it over the drive
	rem   2. Apps: tries every _Data\Apps\<App> folder, running its update.cmd from inside that folder
	rem      (folders without an update.cmd are skipped)
	rem Usage: Update-Tool.cmd [/scripts ^| /apps]   (no argument = update both)
	rem Files on the drive that aren't in the repo (eg. the apps themselves) are never deleted
	rem Scripts on the drive are overwritten with the repo version, so make local changes in the repo
	rem placeholder.file files are not copied to the drive
	rem Update-Tool.cmd updates itself last, because a running batch file can't safely be overwritten


rem Settings
rem ----------------------------------------------------------------------------------------------------
	set "repo=WelFedTed/Technician"
	set "branch=main"
	set "root=%~dp0"
	set "work=%TEMP%\USB-Tool-Update"
	set "src=%work%\Technician-%branch%\USB-Tool_Scripts"
	set "curl=%SystemRoot%\System32\curl.exe"
	set "tar=%SystemRoot%\System32\tar.exe"

	set "doScripts=1"
	set "doApps=1"
	if /i "%~1" == "/scripts" set "doApps=0"
	if /i "%~1" == "/apps" set "doScripts=0"

	set "scriptsResult=skipped"
	set "selfUpdate=0"
	set /a appTotal=0
	set /a appCount=0
	set /a appSkipped=0
	set "appWarnings="


rem Checks
rem ----------------------------------------------------------------------------------------------------
	rem don't overwrite the git checkout this script lives in
	if exist "%root%..\.git\" (
		echo This looks like the git repository, not the USB tool.
		echo Run Update-Tool.cmd from the root of the USB drive.
		pause
		exit /b 1
	)

	call :header "USB Tool Updater"
	echo Drive: %root%
	echo:

	echo Checking internet connection...
	"%curl%" -s -I -o nul --max-time 15 https://github.com
	if errorlevel 1 (
		echo Can't reach github.com. Check the internet connection and try again.
		pause
		exit /b 1
	)
	echo Connected


rem Update
rem ----------------------------------------------------------------------------------------------------
	if "%doScripts%" == "1" (
		call :updateScripts
		if errorlevel 1 ( set "scriptsResult=FAILED" ) else ( set "scriptsResult=updated" )
	)

	if "%doApps%" == "1" call :updateApps

	rem TODO: update PortableApps (the PortableApps folder in the drive root, using portableapps.com releases)
	rem TODO: update Linux + Windows ISOs
	rem TODO: update Ventoy

	goto end


rem Update Scripts
rem ----------------------------------------------------------------------------------------------------
:updateScripts
	call :header "Updating scripts from github.com/%repo% (%branch%)"

	if exist "%work%" rmdir /s /q "%work%"
	mkdir "%work%"

	echo Downloading...
	"%curl%" -L --fail -s -S -o "%work%\repo.zip" "https://github.com/%repo%/archive/refs/heads/%branch%.zip"
	if errorlevel 1 (
		echo Download failed.
		exit /b 1
	)

	echo Extracting...
	"%tar%" -xf "%work%\repo.zip" -C "%work%" "Technician-%branch%/USB-Tool_Scripts/*"
	if not exist "%src%\_Template.cmd" (
		echo Extract failed, or the repo layout has changed.
		exit /b 1
	)

	echo Copying changed files to the drive...
	echo:
	robocopy "%src%" "%root%." /E /XF placeholder.file Update-Tool.cmd /R:1 /W:1 /NJH /NJS /NDL /NP
	if errorlevel 8 (
		echo Copy failed, robocopy exit code !errorlevel!.
		exit /b 1
	)

	rem Update-Tool.cmd is replaced at the very end
	fc /b "%src%\Update-Tool.cmd" "%~f0" >nul 2>&1
	if errorlevel 1 set "selfUpdate=1"

	echo:
	echo Scripts updated
	exit /b 0


rem Update Apps
rem ----------------------------------------------------------------------------------------------------
:updateApps
	call :header "Updating apps"

	rem the update scripts need wget
	where wget >nul 2>&1
	if errorlevel 1 (
		call :installWget
		if errorlevel 1 exit /b 1
	)

	for /d %%D in ("%root%_Data\Apps\*") do call :updateApp "%%~fD"
	exit /b 0

:updateApp
	set /a appTotal+=1
	set "appName=%~nx1"
	rem set the header text directly; passing names with & through call would break them
	set "headerText=[!appTotal!] !appName!"
	call :header

	if not exist "%~1\update.cmd" (
		echo No update.cmd, skipping
		set /a appSkipped+=1
		exit /b 0
	)
	set /a appCount+=1

	pushd "%~1"
	rem .\ is needed on PCs that don't search the current folder for commands
	cmd /d /c .\update.cmd
	popd
	title USB Tool Updater

	rem a failed download leaves a 0 byte file in place of the app
	set "emptyFiles="
	for %%F in ("%~1\*.exe" "%~1\*.msi" "%~1\*.zip") do (
		if %%~zF == 0 set "emptyFiles=!emptyFiles! %%~nxF"
	)
	if defined emptyFiles (
		echo:
		echo WARNING: empty file^(s^) after update:!emptyFiles!
		set "appWarnings=!appWarnings!;!appName!:!emptyFiles!"
	)
	exit /b 0

:installWget
	echo wget not found, installing it with winget...
	where winget >nul 2>&1
	if errorlevel 1 (
		echo winget isn't installed. Install "App Installer" from the Microsoft Store, then run this again.
		exit /b 1
	)
	winget install --id JernejSimoncic.Wget --exact --source winget

	rem pick up the PATH changes winget just made, without opening a new window
	set "PATH=%PATH%;%LOCALAPPDATA%\Microsoft\WinGet\Links"
	for /f "tokens=2,*" %%A in ('reg query "HKCU\Environment" /v Path 2^>nul ^| find "REG_"') do call set "PATH=%%PATH%%;%%B"

	where wget >nul 2>&1
	if errorlevel 1 (
		echo wget still can't be found. Close this window, open a new one and run Update-Tool.cmd again.
		exit /b 1
	)
	exit /b 0


rem Helpers
rem ----------------------------------------------------------------------------------------------------
:header
	echo:
	echo ----------------------------------------------------------------------------------------------------
	rem with no argument, prints headerText (used for app names, which may contain &)
	if not "%~1" == "" set "headerText=%~1"
	echo !headerText!
	echo ----------------------------------------------------------------------------------------------------
	exit /b 0


rem Summary
rem ----------------------------------------------------------------------------------------------------
:end
	call :header "Summary"
	echo Scripts: %scriptsResult%
	if "%doApps%" == "1" ( echo Apps:    !appCount! updated, !appSkipped! skipped ^(no update.cmd^) ) else ( echo Apps:    skipped )
	if defined appWarnings (
		echo:
		echo These apps may not have updated properly ^(empty files left behind^):
		for %%W in ("!appWarnings:;=" "!") do if not "%%~W" == "" echo   %%~W
	)
	echo:

	rem replace this script last; the whole block is read before it runs, so overwriting is safe here
	if "%selfUpdate%" == "1" (
		copy /y "%src%\Update-Tool.cmd" "%~f0" >nul
		rmdir /s /q "%work%" 2>nul
		echo Update-Tool.cmd was also updated.
		echo End of script
		pause
		exit /b 0
	)

	if exist "%work%" rmdir /s /q "%work%"
	echo End of script
	pause
	exit /b 0
