@echo off

title Sublime Text

rem launch correct version depending on architecture (x86 or x64), throw error if no x86 build when running on 32-bit

set dir="_Data\Apps\Sublime Text\"
set app=sublime_text.exe

cd %dir%
start %app%