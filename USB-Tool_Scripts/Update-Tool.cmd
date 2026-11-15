@echo off
setlocal EnableExtensions EnableDelayedExpansion

title USB Tool Updater

rem Notes
rem ----------------------------------------------------------------------------------------------------
	rem Run from the root of the USB tool (eg. Z:\Update-Tool.cmd)
	rem   1. Scripts: downloads the latest USB-Tool_Scripts folder from GitHub and copies it over the drive
	rem   2. Apps: tries every _Data\Apps\<App> folder, running its update.cmd from inside that folder
	rem      (folders without an update.cmd are skipped; folders starting with _ are notes, not apps)
	rem      A folder without an update.cmd can be a group of apps, each in its own folder with its own update.cmd
	rem      (eg. _Data\Apps\Nirsoft\ProduKey, _Data\Apps\Microsoft\Office\2024); these are found too, and shown
	rem      with spaces for the slashes (eg. "Nirsoft ProduKey")
	rem      Several apps are updated at once (parallel, below), by _Data\Apps\_Update-Apps.ps1: each app's
	rem      output goes to a log in the run's folder, and a line is shown as each finishes
	rem      (the report includes the log of any app that needs you)
	rem      Each update.cmd uses the shared helper _Data\Apps\_Update-App.ps1, keeping each kind of download
	rem      in its own folder (Installer, Portable, CLI); apps saved in the old layout (build folders straight
	rem      in the app folder, or folders such as "7-Zip Portable") are moved into these on their next update
	rem      (folders that were merged or renamed, eg. "7-Zip Portable", may show as skipped once afterwards)
	rem   3. Drive: replaces v<date>.version in the drive's root with today's date (eg. v2026-11-14.version),
	rem      a record of when the drive was last updated (skipped if the scripts couldn't be updated)
	rem   4. Report: makes an HTML report and opens it: the run's numbers, what each app did, and what needs
	rem      doing by hand (download links, scripts to run such as Aseprite's build.cmd)
	rem      Each run's report is kept, named for when the run started, eg.
	rem      %TEMP%\USB-Tool-Reports\Update-Report_2026-11-15_18-37-29.html
	rem      (made by _Data\Apps\_Update-Report.ps1, from what each app's update writes to %USB_TOOL_REPORT%)
	rem      If the update is stopped early (Ctrl+C, or closing the window), the report is still made, saying
	rem      where it stopped and which apps weren't tried: a batch file can't run anything once it's stopped,
	rem      so a hidden watcher makes it once the run lets go of running.lock in the run's folder
	rem Usage: Update-Tool.cmd [/scripts ^| /apps]   (no argument = update both)
	rem Files on the drive that aren't in the repo (eg. the apps themselves) are never deleted
	rem Scripts on the drive are overwritten with the repo version, so make local changes in the repo
	rem .gitkeep files (which only make git keep otherwise-empty folders) are not copied to the drive
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
	rem the reports (one per run, kept), and this run's details for its report (in Run, replaced each run)
	rem (not USB-Tool-Report, which older versions of this script delete as they start)
	set "reportDir=%TEMP%\USB-Tool-Reports"
	set "runDir=%reportDir%\Run"
	set "USB_TOOL_REPORT=%runDir%\results.jsonl"
	set "appsList=%runDir%\apps.txt"
	rem every app folder this run will try, and how far it got (for the report if it's stopped early)
	set "appsPlan=%runDir%\plan.txt"
	set "runState=%runDir%\state.txt"
	rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
	set "PSModulePath="
	rem how many apps to update at once (most of each app's check is waiting for its website; 1 = one at a time)
	set "parallel=6"

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

	rem a fresh folder for this run's details (the reports next to it are kept)
	if exist "%runDir%" rmdir /s /q "%runDir%"
	mkdir "%runDir%"
	type nul > "%appsList%"
	rem (-Begin also starts the hidden watcher that makes the report if this run is stopped early)
	if exist "%root%_Data\Apps\_Update-Report.ps1" powershell -NoProfile -ExecutionPolicy Bypass -File "%root%_Data\Apps\_Update-Report.ps1" -Begin -DataDir "%runDir%" -OutDir "%reportDir%" -Root "%root%." -DoScripts "%doScripts%" -DoApps "%doApps%"


rem Update
rem ----------------------------------------------------------------------------------------------------
	rem the run keeps running.lock open until it's done, so the watcher can tell when it was stopped
	rem (if the lock can't be made, the update still runs, just without a report when it's stopped)
	set "ran=0"
	call :run 9>"%runDir%\running.lock"
	if "!ran!" == "0" call :run
	goto end

:run
	set "ran=1"
	if "%doScripts%" == "1" (
		call :updateScripts
		if errorlevel 1 ( set "scriptsResult=FAILED" ) else ( set "scriptsResult=updated" )
		>>"%runState%" echo scripts=!scriptsResult!
		>>"%runState%" echo selfUpdate=!selfUpdate!
	)

	if "%doApps%" == "1" call :updateApps

	rem TODO: update PortableApps (the PortableApps folder in the drive root, using portableapps.com releases)
	rem TODO: update Linux + Windows ISOs
	rem TODO: upgrade Ventoy on this drive itself (the Ventoy app files are already updated in _Data\Apps\Ventoy)

	>>"%runState%" echo step=finish
	call :summary
	exit /b 0


rem Update Scripts
rem ----------------------------------------------------------------------------------------------------
:updateScripts
	call :header "Updating scripts from github.com/%repo% (%branch%)"
	>>"%runState%" echo step=scripts

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
	robocopy "%src%" "%root%." /E /XF .gitkeep Update-Tool.cmd v.version /R:1 /W:1 /NJH /NJS /NDL /NP
	if errorlevel 8 (
		echo Copy failed, robocopy exit code !errorlevel!.
		exit /b 1
	)

	rem folders renamed in the repo: move what's in the old folder on the drive into the new one
	call :moveFolder "_Data\Apps\Microsoft Activiation Scripts (MAS)" "_Data\Apps\Microsoft Activation Scripts (MAS)"
	call :moveFolder "_Data\Apps\7zip" "_Data\Apps\7-Zip"
	call :moveFolder "_Data\Apps\7zip CLI" "_Data\Apps\7-Zip CLI"
	rem the NirSoft tools, moved from "_Data\Apps\Nirsoft <tool>" into the Nirsoft group folder (eg.
	rem _Data\Apps\Nirsoft\ProduKey); only those the repo has there, so a tool added by hand keeps its own update.cmd
	for /d %%F in ("%root%_Data\Apps\Nirsoft *") do (
		set "tool=%%~nxF"
		set "tool=!tool:~8!"
		if exist "%root%_Data\Apps\Nirsoft\!tool!\update.cmd" call :moveFolder "_Data\Apps\%%~nxF" "_Data\Apps\Nirsoft\!tool!"
	)
	call :moveFolder "_Data\Apps\NirLauncher" "_Data\Apps\Nirsoft\NirLauncher"
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
	call :header "Updating apps (%parallel% at a time)"
	if not exist "%root%_Data\Apps\_Update-Apps.ps1" (
		echo _Data\Apps\_Update-Apps.ps1 is missing, so the apps can't be updated. Run Update-Tool.cmd /scripts first.
		exit /b 0
	)
	rem (it writes plan.txt, apps.txt and state.txt in the run's folder; each app's output is in its logs folder)
	powershell -NoProfile -ExecutionPolicy Bypass -File "%root%_Data\Apps\_Update-Apps.ps1" -AppsDir "%root%_Data\Apps" -RunDir "%runDir%" -Parallel %parallel%
	title USB Tool Updater

	rem the summary's numbers, from each app's line in apps.txt: <update.cmd's exit code, or skip>*<name>
	rem update.cmd exit codes: 0 = updated or up to date, 2 = needs a manual update,
	rem 3 = updated but Windows Defender blocked some files, anything else = failed
	rem (* can't be in a folder name, so it separates the fields)
	if not exist "%appsList%" exit /b 0
	for /f "usebackq tokens=1* delims=*" %%A in ("%appsList%") do (
		set /a appTotal+=1
		set "appResult=%%A"
		set "appName=%%B"
		if "!appResult!" == "skip" (
			set /a appSkipped+=1
		) else if "!appResult!" == "0" (
			set /a appCount+=1
		) else if "!appResult!" == "3" (
			set /a appCount+=1
			set "appBlocked=!appBlocked!;!appName!"
		) else if "!appResult!" == "2" (
			set "appManual=!appManual!;!appName!"
		) else (
			set "appFailed=!appFailed!;!appName!"
		)
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
	>>"%runState%" echo stamp=!stampName!
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
:summary
	rem the drive's "last updated" file (eg. v2026-11-14.version), unless the script update failed, or the apps
	rem were stopped part-way (Ctrl+C, then N to carry on)
	set "appsStopped=0"
	if exist "%runState%" findstr /x /c:"stopped=1" "%runState%" >nul && set "appsStopped=1"
	set "stampName="
	if not "%scriptsResult%" == "FAILED" if "!appsStopped!" == "0" call :stampDrive
	rem the app updates download and unpack in _Data\Temp on the drive; remove it once it's empty
	rmdir "%root%_Data\Temp" 2>nul

	call :header "Summary"
	if defined stampName echo Drive:   last updated !stampName:~1,10! ^(!stampName!^)
	echo Scripts: %scriptsResult%
	if "%doApps%" == "1" ( echo Apps:    !appCount! updated or already up to date, !appSkipped! skipped ^(no update.cmd^) ) else ( echo Apps:    skipped )
	if "!appsStopped!" == "1" echo          STOPPED part-way, so not every app was updated ^(the drive's "last updated" date wasn't changed^)
	if defined appFailed (
		echo:
		echo These apps FAILED to update ^(the report says why^):
		for %%W in ("!appFailed:;=" "!") do if not "%%~W" == "" echo   %%~W
	)
	if defined appBlocked (
		echo:
		echo These apps updated, but Windows Defender blocked some of their files ^(the report lists which^):
		for %%W in ("!appBlocked:;=" "!") do if not "%%~W" == "" echo   %%~W
	)
	if defined appManual (
		echo:
		echo These apps need updating by hand ^(the report says where to get them^):
		for %%W in ("!appManual:;=" "!") do if not "%%~W" == "" echo   %%~W
	)
	echo:

	rem the HTML report (opened at the end, once the run has let go of running.lock)
	>>"%runState%" echo step=report
	if exist "%root%_Data\Apps\_Update-Report.ps1" (
		powershell -NoProfile -ExecutionPolicy Bypass -File "%root%_Data\Apps\_Update-Report.ps1" -DataDir "%runDir%" -OutDir "%reportDir%" -Root "%root%." -Scripts "%scriptsResult%" -SelfUpdate "%selfUpdate%" -DoApps "%doApps%" -Stamp "!stampName!"
		echo:
	)
	exit /b 0


rem End
rem ----------------------------------------------------------------------------------------------------
:end
	rem the report, in the default browser
	rem (its name, which has the time the run started in it, is in report.txt)
	set "reportFile="
	if exist "%runDir%\report.txt" set /p reportFile=<"%runDir%\report.txt"
	if defined reportFile if exist "!reportFile!" start "" "!reportFile!"

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
