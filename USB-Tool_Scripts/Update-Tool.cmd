@echo off
setlocal EnableExtensions EnableDelayedExpansion

title USB Tool Updater

rem Notes
rem ----------------------------------------------------------------------------------------------------
	rem Run from the root of the USB tool (eg. Z:\Update-Tool.cmd)
	rem   1. Scripts: downloads the latest USB-Tool_Scripts folder from GitHub and copies it over the drive
	rem   2. Apps: tries every _Data\Apps\<App> folder, running its update.cmd from inside that folder
	rem      (folders without an update.cmd are skipped; folders starting with _ are notes, not apps)
	rem      Each update.cmd uses the shared helper _Data\Apps\_Update-App.ps1, keeping each kind of download
	rem      in its own folder (Installer, Portable, CLI); apps saved in the old layout (build folders straight
	rem      in the app folder, or folders such as "7-Zip Portable") are moved into these on their next update
	rem      (folders that were merged or renamed, eg. "7-Zip Portable", may show as skipped once afterwards)
	rem   3. Drive: replaces v<date>.version in the drive's root with today's date (eg. v2026-11-14.version),
	rem      a record of when the drive was last updated (skipped if the scripts couldn't be updated)
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
	set "appBlocked="


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
	rem (v.version is the repo's stand-in for the drive's dated "last updated" file, written at the end)
	robocopy "%src%" "%root%." /E /XF placeholder.file Update-Tool.cmd v.version /R:1 /W:1 /NJH /NJS /NDL /NP
	if errorlevel 8 (
		echo Copy failed, robocopy exit code !errorlevel!.
		exit /b 1
	)

	rem folders renamed in the repo: move what's in the old folder on the drive into the new one
	call :moveFolder "_Data\Apps\Microsoft Activiation Scripts (MAS)" "_Data\Apps\Microsoft Activation Scripts (MAS)"
	call :moveFolder "_Data\Apps\7zip" "_Data\Apps\7-Zip"
	call :moveFolder "_Data\Apps\7zip CLI" "_Data\Apps\7-Zip CLI"
	rem folders whose name only changed case: Windows sees them as the same folder, so just rename
	call :renameCase "_Data\Apps" "RKill"

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

	rem update.cmd exit codes: 0 = updated or up to date, 2 = needs a manual update,
	rem 3 = updated but Windows Defender blocked some files, anything else = failed
	if "!appResult!" == "0" (
		set /a appCount+=1
	) else if "!appResult!" == "3" (
		set /a appCount+=1
		set "appBlocked=!appBlocked!;!appName!"
	) else if "!appResult!" == "2" (
		set "appManual=!appManual!;!appName!"
	) else (
		set "appFailed=!appFailed!;!appName!"
	)
	exit /b 0


rem Helpers
rem ----------------------------------------------------------------------------------------------------
rem fixes the capitalisation of a folder's name, eg. Rkill to RKill (no-op if it's already right)
:renameCase
	if not exist "%root%%~1\%~2\" exit /b 0
	rem list with a wildcard so Windows returns the name as it's actually written on the drive
	set "currentName="
	for /d %%D in ("%root%%~1\*") do if /i "%%~nxD" == "%~2" set "currentName=%%~nxD"
	if "!currentName!" == "%~2" exit /b 0
	echo:
	echo Renaming !currentName! to %~2...
	ren "%root%%~1\!currentName!" "%~2"
	exit /b 0

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
	rem robocopy /MOVE usually removes the old folder itself; this catches anything it skipped
	if exist "%root%%~1\" rmdir /s /q "%root%%~1"
	exit /b 0

rem replaces the drive's v<date>.version file (in its root) with one for today, eg. v2026-11-14.version,
rem as a record of when the drive was last updated
:stampDrive
	set "today="
	rem (.NET's date rather than %date%, whose format depends on the PC's region settings)
	for /f %%D in ('powershell -NoProfile -Command "[DateTime]::Now.ToString('yyyy-MM-dd')"') do set "today=%%D"
	if not defined today (
		echo Couldn't get today's date, so the drive's version file wasn't updated.
		exit /b 0
	)
	del /q "%root%v*.version" 2>nul
	type nul > "%root%v%today%.version"
	set "stampName=v%today%.version"
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
	rem the drive's "last updated" file (eg. v2026-11-14.version), unless the script update failed
	set "stampName="
	if not "%scriptsResult%" == "FAILED" call :stampDrive

	call :header "Summary"
	if defined stampName echo Drive:   last updated !stampName:~1,10! ^(!stampName!^)
	echo Scripts: %scriptsResult%
	if "%doApps%" == "1" ( echo Apps:    !appCount! updated or already up to date, !appSkipped! skipped ^(no update.cmd^) ) else ( echo Apps:    skipped )
	if defined appFailed (
		echo:
		echo These apps FAILED to update ^(scroll up for the reason^):
		for %%W in ("!appFailed:;=" "!") do if not "%%~W" == "" echo   %%~W
	)
	if defined appBlocked (
		echo:
		echo These apps updated, but Windows Defender blocked some of their files ^(scroll up for which^):
		for %%W in ("!appBlocked:;=" "!") do if not "%%~W" == "" echo   %%~W
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
