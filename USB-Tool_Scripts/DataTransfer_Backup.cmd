@REM Checks if running as Admin, then passes the directory to "DataTransfer_Backup.ps1"
@REM Run from folder you wish to export / backup to

@echo off

title Data Transfer - Backup Script

echo Data Transfer - Backup Script
echo ----------------------------------------------------------------------
echo:

@REM update DataTransfer_Backup.cmd
echo Checking for latest version of DataTransfer_Backup.cmd...
powershell -Command "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/WelFedTed/Technician/refs/heads/main/USB-Tool_Scripts/DataTransfer_Backup.cmd' -OutFile '%temp%\DataTransfer_Backup_latest.cmd'"
fc "%temp%\DataTransfer_Backup_latest.cmd" "%~dp0\DataTransfer_Backup.cmd" >nul
if errorlevel 1 (
    echo A newer version of DataTransfer_Backup.cmd is available
    echo Updating...
    move /Y "%temp%\DataTransfer_Backup_latest.cmd" "%~dp0\DataTransfer_Backup.cmd" >nul
    echo Restarting script...
    "%~dp0\DataTransfer_Backup.cmd" %*
    exit /b
) else (
    echo You already have the latest version of DataTransfer_Backup.cmd
    echo Proceeding...
    del "%temp%\DataTransfer_Backup_latest.cmd"
)
echo:

@REM update DataTransfer_Backup.ps1
echo Checking for latest version of DataTransfer_Backup.ps1...
powershell -Command "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/WelFedTed/Technician/refs/heads/main/USB-Tool_Scripts/DataTransfer_Backup.ps1' -OutFile '%temp%\DataTransfer_Backup_latest.ps1'"
fc "%temp%\DataTransfer_Backup_latest.ps1" "%~dp0\DataTransfer_Backup.ps1" >nul
if errorlevel 1 (
    echo A newer version of DataTransfer_Backup.ps1 is available
    echo Updating...
    move /Y "%temp%\DataTransfer_Backup_latest.ps1" "%~dp0\DataTransfer_Backup.ps1" >nul
) else (
    echo You already have the latest version of DataTransfer_Backup.ps1
    echo Proceeding...
    del "%temp%\DataTransfer_Backup_latest.ps1"
)
echo:

echo Checking if you have Administrator permissions...
echo:

rem check if already elevated
NET FILE 1>NUL 2>NUL
if '%errorlevel%' == '0' ( goto gotPrivileges ) else ( goto getPrivileges )

:getPrivileges
rem not elevated, relaunch as admin
pushd "%CD%"
echo Not currently elevated, requesting Administrator access...
powershell -command start-process -file %~f0 %cd% -verb runas
exit /b

:gotPrivileges
if "%~1" == "" (
    set "currentDir=%cd%"
) else (
    set "currentDir=%~1"
)
rem is elevated, continue script
echo Running as Administrator, proceeding...
echo:
echo You are about to run the Data Transfer Backup script.
echo Backup data will be saved to the following directory:
echo:
echo %currentDir%
echo:
choice /c YN /n /m "Are you sure you want to continue? (Y/N): "

IF ERRORLEVEL 2 GOTO NO_CONTINUE
IF ERRORLEVEL 1 GOTO CONTINUE

:CONTINUE
pushd "%~dp0"
PowerShell.exe -Command "& {Start-Process PowerShell.exe -ArgumentList '-NonInteractive -NoProfile -ExecutionPolicy Bypass -File "%~dp0\%~n0.ps1 %currentDir%"' -Verb RunAs}"
goto END

:NO_CONTINUE
echo Exiting...
goto END

:END
exit /b