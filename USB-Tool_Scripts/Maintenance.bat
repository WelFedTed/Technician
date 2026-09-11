@echo off

title Maintenance Script

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
echo:


echo Performing system maintenance tasks...
echo:

echo Updating system packages...
topgrade --yes --no-ask-retry --disable system bin
echo:
title Maintenance Script

echo Updating package sources...
winget source update
echo:

echo Upgrading all packages...
winget upgrade --all --silent
echo:

echo Running system file checker (1st round)...
sfc /scannow
echo:

echo Running DISM cleanup...
dism /online /cleanup-image /startcomponentcleanup /resetbase
echo:

echo Running DISM restore health...
dism /online /cleanup-image /restorehealth
echo:

echo Running system file checker (2nd round)...
sfc /scannow

echo Running disk cleanup...
cleanmgr /sagerun:10
echo:

echo Running disk defragmentation (all disks)...
defrag /c /o /h /u /v
echo:

echo Running disk check (C: drive only)...
chkdsk c: /r /scan /perf
echo:

echo:
echo Maintenance completed.
pause
exit /b