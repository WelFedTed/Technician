@echo off

title Snappy Driver Installer Origin

rem launch correct version depending on architecture (x86 or x64)

set dir="_Data\Apps\Snappy Driver Installer Origin\"
set app=SDIO_auto.bat

cd %dir%
%app%