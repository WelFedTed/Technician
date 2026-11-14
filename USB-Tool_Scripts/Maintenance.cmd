@echo off

title Maintenance Script

rem Runs _Data\Scripts\maintenance.cmd from the USB tool this launcher is in (it asks to run as admin)
start "" "%~dp0_Data\Scripts\maintenance.cmd"
exit /b
