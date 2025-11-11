@REM Checks if running as Admin, then passes the directory to "DataTransfer_Backup.ps1"
@REM Run from folder you wish to export / backup to

@echo off

title Data Transfer - Backup Script

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
pushd "%~dp0"
PowerShell.exe -Command "& {Start-Process PowerShell.exe -ArgumentList '-NonInteractive -NoProfile -ExecutionPolicy Bypass -File "%~dp0\%~n0.ps1 %currentDir%"' -Verb RunAs}"
exit /b