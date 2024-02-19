@echo off

title Ungoogled Chromium

rem launch correct version depending on architecture (x86 or x64)

set dir="_Data\Apps\Ungoogled Chromium\"
set app=ungoogled-chromium-portable.exe

cd %dir%
start %app%