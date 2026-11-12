@echo off
setlocal EnableExtensions EnableDelayedExpansion

title USB Tool Updater

rem Notes
rem ----------------------------------------------------------------------------------------------------
	rem Run from the root of the USB tool (eg. Z:\Update-Tool.cmd)
	rem   1. Scripts: downloads the latest USB-Tool_Scripts folder from GitHub and copies it over the drive
	rem   2. Apps: tries every _Data\Apps\<App> folder, running its update.cmd from inside that folder
	rem      (folders without an update.cmd are skipped; folders starting with _ are notes, not apps)
	rem      Each update.cmd uses the shared helper _Data\Apps\_Update-App.ps1
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
	set "appFailed="
	set "appManual="


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
	rem TODO: upgrade Ventoy on this drive itself (the Ventoy app files are already updated in _Data\Apps\Ventoy)

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

	rem folders renamed in the repo: move what's in the old folder on the drive into the new one
	call :moveFolder "_Data\Apps\Microsoft Activiation Scripts (MAS)" "_Data\Apps\Microsoft Activation Scripts (MAS)"

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

	rem folders starting with _ are notes (eg. "_need a portable pdf reader"), not apps
	for /d %%D in ("%root%_Data\Apps\*") do (
		set "folderName=%%~nxD"
		if not "!folderName:~0,1!" == "_" call :updateApp "%%~fD"
	)
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

	pushd "%~1"
	rem .\ is needed on PCs that don't search the current folder for commands
	cmd /d /c .\update.cmd /nopause
	set "appResult=!errorlevel!"
	popd
	title USB Tool Updater

	rem update.cmd exit codes: 0 = updated or up to date, 2 = needs a manual update, anything else = failed
	if "!appResult!" == "0" (
		set /a appCount+=1
	) else if "!appResult!" == "2" (
		set "appManual=!appManual!;!appName!"
	) else (
		set "appFailed=!appFailed!;!appName!"
	)
	exit /b 0


rem Helpers
rem ----------------------------------------------------------------------------------------------------
rem moves an old folder's contents into its renamed folder (keeping the repo's update.cmd), then deletes it
:moveFolder
	if not exist "%root%%~1\" exit /b 0
	echo:
	echo Moving %~1 to its new name...
	robocopy "%root%%~1" "%root%%~2" /E /MOVE /XF update.cmd /R:1 /W:1 /NJH /NJS /NDL /NFL /NP >nul
	if errorlevel 8 (
		echo Couldn't move everything, so "%~1" was left in place.
		exit /b 0
	)
	rmdir /s /q "%root%%~1"
	exit /b 0

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
	if "%doApps%" == "1" ( echo Apps:    !appCount! updated or already up to date, !appSkipped! skipped ^(no update.cmd^) ) else ( echo Apps:    skipped )
	if defined appFailed (
		echo:
		echo These apps FAILED to update ^(scroll up for the reason^):
		for %%W in ("!appFailed:;=" "!") do if not "%%~W" == "" echo   %%~W
	)
	if defined appManual (
		echo:
		echo These apps need updating by hand ^(scroll up for where to get them^):
		for %%W in ("!appManual:;=" "!") do if not "%%~W" == "" echo   %%~W
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
