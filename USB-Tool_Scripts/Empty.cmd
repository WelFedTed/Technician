@echo off

title Empty Recycle Bin

rem Runs _Data\Scripts\empty-recycle-bin.cmd from the USB tool this launcher is in
start "" "%~dp0_Data\Scripts\empty-recycle-bin.cmd"
exit /b
