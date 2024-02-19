@echo off

title VLC Media Player

rem launch correct version depending on architecture (x86 or x64)
rem current files downloaded are 32-bit

set dir="_Data\Apps\VLC Media Player\"
set app=vlc.exe

cd %dir%
start %app%
exit /b