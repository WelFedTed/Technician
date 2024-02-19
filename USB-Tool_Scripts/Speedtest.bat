@echo off

title Speedtest

rem launch correct version depending on architecture (x86 or x64)

set dir="_Data\Apps\Speedtest CLI\"
set app=speedtest.exe

cd %dir%
%app%

pause