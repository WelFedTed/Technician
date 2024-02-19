@echo off

title iPerf

rem launch correct version depending on architecture (x86 or x64)

set dir="_Data\Apps\iPerf\x64\"
set app=iperf3.exe
set server=10.0.3.21

cd %dir%
%app% -c %server%

pause
exit /b