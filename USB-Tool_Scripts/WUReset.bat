@echo off

title Reset Windows Update Tool

rem launch correct version depending on architecture (x86 or x64)

set dir="_Data\Apps\Reset Windows Update Tool (wureset)"
set app=wureset.exe

cd %dir%
%app%