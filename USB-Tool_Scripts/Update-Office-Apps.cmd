@echo off

title Update Office Apps

rem Runs _Data\Scripts\update-office-apps.cmd from the USB tool this launcher is in
start "" "%~dp0_Data\Scripts\update-office-apps.cmd"
exit /b
