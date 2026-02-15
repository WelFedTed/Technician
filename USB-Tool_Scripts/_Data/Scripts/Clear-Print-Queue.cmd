@echo off
title COPS - Clearing Print Queue

rem check if elevated
NET FILE 1>NUL 2>NUL
if '%errorlevel%' == '0' ( goto gotPrivileges ) else ( goto getPrivileges )

:getPrivileges
rem not elevated, relaunch as admin
powershell -command start-process -file %~f0 -verb runas
exit /b

:gotPrivileges

echo Stopping print spooler service...
net stop spooler
echo Clearing print queue...
del %systemroot%\System32\spool\printers\* /Q
echo:
net start spooler

echo:
echo Print queue cleared successfully.
echo:
pause
exit /b