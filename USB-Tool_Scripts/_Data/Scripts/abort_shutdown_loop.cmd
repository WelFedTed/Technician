@echo off

REM Updated: 04-10-2019

title Abort Windows Shutdown

set timer=5

:start
echo Aborting Windows Shutdown...
shutdown -a
goto:wait

:wait
timeout /t %timer% /nobreak
echo:
goto:start