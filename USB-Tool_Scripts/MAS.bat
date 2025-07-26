@echo off

title Microsoft Activation Scripts

rem launch correct version depending on architecture (x86 or x64)

set dir="_Data\Apps\Microsoft Activiation Scripts (MAS)\Microsoft-Activation-Scripts-master\MAS\All-In-One-Version-KL"
set app=MAS_AIO.cmd

cd %dir%
%app%