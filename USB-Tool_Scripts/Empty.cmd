@echo off

title Empty Recycle Bin

rem Runs _Data\Scripts\empty-recycle-bin.cmd from the USB tool this launcher is in
rem (in a new window, by its full path: start "" "<path>" can't start a script whose path has a & in it, and
rem  start /d "<folder>" <name> would run a script of the same name on the PATH first)
start "" "%ComSpec%" /d /c call "%~dp0_Data\Scripts\empty-recycle-bin.cmd"
exit /b
