@echo off

title Empty Recycle Bin

rem Runs _Data\Scripts\empty-recycle-bin.cmd from the drive this launcher is on
start "" "%~d0\_Data\Scripts\empty-recycle-bin.cmd"
exit /b
