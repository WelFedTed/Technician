@echo off

title Clear Print Queue

rem Runs _Data\Scripts\Clear-Print-Queue.cmd from the USB tool this launcher is in (it asks to run as admin)
start "" "%~dp0_Data\Scripts\Clear-Print-Queue.cmd"
exit /b
