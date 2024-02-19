@echo off

title Microsoft Activation Scripts

rem launch correct version depending on architecture (x86 or x64)

set dir="_Data\Apps\Microsoft Activiation Scripts\All-In-One-Version\"
set app=MAS_AIO.cmd

cd %dir%
%app%