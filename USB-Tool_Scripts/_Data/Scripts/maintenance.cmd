@echo off
rem keep the script's variables (log, stepname, ...) out of the calling console
setlocal

title Maintenance Script

rem check if already elevated
rem (fltmc only succeeds as administrator; unlike NET FILE it doesn't depend on
rem  the Server service, which made elevated runs look non-elevated when stopped)
fltmc >nul 2>&1
if not errorlevel 1 goto gotPrivileges

rem The relaunched copy is marked with /elevated. If it still isn't elevated,
rem stop here instead of relaunching itself over and over.
if /i "%~1"=="/elevated" goto elevationFailed

:getPrivileges
rem not elevated, relaunch as admin
rem (path is quoted so folders with spaces work; any ' is doubled because it
rem  sits inside a PowerShell single-quoted string)
set "self=%~f0"
powershell -NoProfile -Command "try { Start-Process -FilePath '%self:'=''%' -ArgumentList '/elevated' -Verb RunAs -ErrorAction Stop } catch { exit 1 }"
if errorlevel 1 (
    echo *** Administrator rights were not granted ^(the UAC prompt was declined^).
    echo *** Maintenance was not run.
    pause
    exit /b 1
)
exit /b

:elevationFailed
echo *** Still not running as administrator after relaunching.
echo *** Maintenance was not run. Try right-clicking the script and choosing
echo *** "Run as administrator".
pause
exit /b 1

:gotPrivileges
rem is elevated, continue script
echo Running as Administrator
echo:

rem ---------------------------------------------------------------------------
rem Log: one line per step with its result and exit code, plus drive health and
rem restart status. (Full tool output stays on screen only: piping it to a file
rem garbles SFC's output and changes how topgrade/winget display progress.)
rem ---------------------------------------------------------------------------
set "logdir=%LOCALAPPDATA%\maintenance-logs"
if not exist "%logdir%" mkdir "%logdir%"
for /f %%d in ('powershell -NoProfile -Command "Get-Date -Format yyyy-MM-dd_HHmm"') do set "stamp=%%d"
set "log=%logdir%\maintenance-%stamp%.log"
>"%log%" echo Maintenance run started %date% %time%
set /a attention=0
set "restart="

echo Performing system maintenance tasks...
echo:

rem Restore point first, so there's a way back if an update breaks something.
rem Needs System Protection on C:, and Windows allows only one per 24 hours
rem (a second attempt creates nothing, only prints a warning, and still exits 0 -
rem the warning is caught and reported with exit code 2, so the summary shows
rem that no new restore point exists instead of logging "OK").
rem Maintenance continues either way.
call :begin "Creating restore point"
powershell -NoProfile -Command "Checkpoint-Computer -Description 'Before maintenance' -RestorePointType MODIFY_SETTINGS -ErrorAction Stop -WarningAction SilentlyContinue -WarningVariable w; if ($w) { $m = '  No restore point created: ' + $w[0].Message; Write-Output $m; Add-Content -LiteralPath $env:log -Value $m; exit 2 }; Write-Output '  Restore point created.'"
call :end %errorlevel%

rem topgrade also updates winget packages and Microsoft Store apps (it runs
rem "store updates --apply" right after its WinGet step), so winget and the
rem Store CLI are only run directly when topgrade isn't installed
where topgrade >nul 2>&1
if errorlevel 1 goto noTopgrade

call :begin "Updating system packages (topgrade)"
topgrade --yes --no-ask-retry --disable system bin
call :end %errorlevel%
title Maintenance Script
goto packagesDone

:noTopgrade
echo topgrade not found, updating packages with winget...
echo:

call :begin "Updating package sources (winget)"
winget source update --disable-interactivity
call :end %errorlevel%

rem (-1978335189 = 0x8A15002B "no applicable update", i.e. nothing to upgrade)
call :begin "Upgrading all packages (winget)"
winget upgrade --all --silent --accept-source-agreements --accept-package-agreements
call :end %errorlevel% "0 -1978335189"

rem Microsoft Store apps, via the Store CLI (store.exe, built into recent
rem Windows 11). --apply installs the updates without asking; without it the
rem CLI stops at a "install now? [y/n]" prompt.
where store >nul 2>&1
if errorlevel 1 goto noStoreCli
call :begin "Updating Microsoft Store apps (store)"
store updates --apply
call :end %errorlevel%
goto packagesDone

:noStoreCli
echo Microsoft Store CLI not found, skipping Store app updates.
>>"%log%" echo [SKIP]  Updating Microsoft Store apps - store CLI not installed
echo:

:packagesDone

rem Repair the component store first: SFC repairs system files from it, so
rem it must be healthy before SFC runs. Then clean it up, then run SFC once.
rem (DISM exit code 3010 = success, restart required)
call :begin "Running DISM restore health"
dism /online /cleanup-image /restorehealth
call :end %errorlevel% "0 3010"

rem (no /resetbase: it makes all currently installed updates permanent, so a
rem  bad update could never be uninstalled)
call :begin "Running DISM component cleanup"
dism /online /cleanup-image /startcomponentcleanup
call :end %errorlevel% "0 3010"

call :begin "Running system file checker"
sfc /scannow
call :end %errorlevel%

rem Disk cleanup uses a fixed list of categories, so it works the same on any
rem PC without running "cleanmgr /sageset:10" first. The script writes profile
rem 10 itself: listed categories are switched on (StateFlags0010 = 2) and every
rem other category on the PC is switched off (0), so leftovers from an earlier
rem /sageset don't creep in. Names are the subkeys of
rem   HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches
rem Categories a PC doesn't have are skipped. To change what gets cleaned, edit
rem this list. (Not included: System error memory dump files, System error
rem minidump files, User file versions.)
set "cleanup_cats=Active Setup Temp Folders"
set "cleanup_cats=%cleanup_cats%;BranchCache"
set "cleanup_cats=%cleanup_cats%;D3D Shader Cache"
set "cleanup_cats=%cleanup_cats%;Delivery Optimization Files"
set "cleanup_cats=%cleanup_cats%;Diagnostic Data Viewer database files"
set "cleanup_cats=%cleanup_cats%;Downloaded Program Files"
set "cleanup_cats=%cleanup_cats%;Feedback Hub Archive log files"
set "cleanup_cats=%cleanup_cats%;Internet Cache Files"
set "cleanup_cats=%cleanup_cats%;Language Pack"
set "cleanup_cats=%cleanup_cats%;Old ChkDsk Files"
set "cleanup_cats=%cleanup_cats%;Recycle Bin"
set "cleanup_cats=%cleanup_cats%;RetailDemo Offline Content"
set "cleanup_cats=%cleanup_cats%;Setup Log Files"
set "cleanup_cats=%cleanup_cats%;Temporary Files"
set "cleanup_cats=%cleanup_cats%;Thumbnail Cache"
set "cleanup_cats=%cleanup_cats%;Update Cleanup"
set "cleanup_cats=%cleanup_cats%;Windows Defender"
set "cleanup_cats=%cleanup_cats%;Windows Error Reporting Files"

call :begin "Configuring disk cleanup categories"
powershell -NoProfile -Command "$on = $env:cleanup_cats -split ';'; $keys = @(Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches' -ErrorAction Stop); foreach ($k in $keys) { $v = if ($on -contains $k.PSChildName) { 2 } else { 0 }; Set-ItemProperty -LiteralPath $k.PSPath -Name StateFlags0010 -Value $v -Type DWord -ErrorAction Stop }; $names = $keys.PSChildName; $used = @($on | Where-Object { $names -contains $_ }); $missing = @($on | Where-Object { $names -notcontains $_ }); Write-Output ('  {0} categories enabled, {1} disabled' -f $used.Count, ($keys.Count - $used.Count)); if ($missing) { Write-Output ('  Not on this PC (skipped): ' + ($missing -join ', ')) }"
call :end %errorlevel%

call :begin "Running disk cleanup"
cleanmgr /sagerun:10
call :end %errorlevel%

rem Fixed NTFS drives, used by both disk optimization and disk check. (defrag /c
rem would also try volumes that can't be optimized, e.g. a FAT32 USB stick, and
rem could end with an error code every run.) Falls back to C: if the list can't
rem be read.
set "drives="
for /f %%v in ('powershell -NoProfile -Command "Get-Volume | Where-Object { $_.FileSystem -eq 'NTFS' -and $_.DriveLetter -and $_.DriveType -eq 'Fixed' } | Sort-Object DriveLetter | ForEach-Object { $_.DriveLetter }"') do call :addDrive %%v
if not defined drives set "drives=C"
echo Fixed NTFS drives: %drives%
echo:

rem /o = the right optimization per drive type (TRIM for SSDs, defrag for HDDs)
for %%v in (%drives%) do call :optimizeDrive %%v

rem Drive health as reported by the drives themselves (SMART / NVMe status)
call :begin "Checking drive health"
powershell -NoProfile -Command "$d = @(Get-PhysicalDisk); foreach ($x in $d) { $l = '  {0} - {1}, {2}: {3}' -f $x.FriendlyName, $x.MediaType, $x.BusType, $x.HealthStatus; Write-Output $l; Add-Content -LiteralPath $env:log -Value $l }; if (-not $d -or ($d | Where-Object HealthStatus -ne 'Healthy')) { exit 1 }"
call :end %errorlevel%

rem Online scan of every fixed NTFS drive. /r can't run while Windows is using
rem a drive, so chkdsk would stop and ask to schedule a full (hours-long) scan at
rem the next restart. If a scan finds problems, it says so; repair them with
rem   chkdsk X: /spotfix
for %%v in (%drives%) do call :scanDrive %%v

rem Restart needed? (pending component servicing, Windows Update, or files
rem queued to be replaced at boot)
reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending" >nul 2>&1 && set "restart=1"
reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired" >nul 2>&1 && set "restart=1"
reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager" /v PendingFileRenameOperations >nul 2>&1 && set "restart=1"

echo:
echo ===========================================================================
echo Maintenance completed.
>>"%log%" echo Maintenance run finished %date% %time%
if %attention% equ 0 goto summaryOk
echo:
echo %attention% step(s) need attention (non-zero exit code - check their output):
findstr /b /c:"[CHECK]" "%log%"
goto summaryRestart
:summaryOk
echo All steps finished without errors.
:summaryRestart
if not defined restart goto summaryLog
echo:
echo *** Restart required to finish maintenance.
>>"%log%" echo Restart required to finish maintenance.
:summaryLog
echo:
echo Log: "%log%"
echo ===========================================================================
pause
exit /b


rem ---------------------------------------------------------------------------
rem :begin "name"        - announce a step
rem :end rc ["ok codes"] - record its result (ok codes default to 0)
rem (labels instead of ( ) blocks, so step names may contain parentheses)
rem ---------------------------------------------------------------------------
:begin
set "stepname=%~1"
echo %stepname%...
exit /b 0

:end
set "rc=%~1"
set "okcodes=%~2"
if not defined okcodes set "okcodes=0"
set "ok="
for %%c in (%okcodes%) do if "%rc%"=="%%c" set "ok=1"
if "%rc%"=="3010" set "restart=1"
if defined ok goto endOk
set /a attention+=1
echo *** %stepname% finished with exit code %rc% - check its output above.
>>"%log%" echo [CHECK] %time:~0,8%  %stepname% - exit code %rc%
echo:
exit /b 0
:endOk
>>"%log%" echo [OK]    %time:~0,8%  %stepname%
echo:
exit /b 0

rem :addDrive X - append drive letter X to the drives list
:addDrive
if defined drives (set "drives=%drives% %1") else (set "drives=%1")
exit /b 0

rem :optimizeDrive X - optimize drive X: (TRIM / defrag as suited)
:optimizeDrive
call :begin "Optimizing drive %1:"
defrag %1: /o /h /u /v
call :end %errorlevel%
exit /b 0

rem :scanDrive X - online chkdsk scan of drive X:
:scanDrive
call :begin "Checking drive %1: - online scan"
chkdsk %1: /scan /perf
call :end %errorlevel%
exit /b 0
