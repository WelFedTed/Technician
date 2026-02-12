@echo off

title Ultra Virus Killer

rem launch correct version depending on architecture (x86 or x64)

set dir="_Data\Apps\Ultra Virus Killer (UVK)"
set app=UVKPortable.exe

cd %dir%
%app%
exit /b