@echo off

title Transwiz

rem check if Windows XP, and run XP one?

set dir="_Data\Apps\Transwiz\"
set app=Transwiz.msi

cd %dir%
start %app%
explorer.exe "%PROGRAMDATA%\ForensiT\Transwiz\Deployment Files\"
exit /b