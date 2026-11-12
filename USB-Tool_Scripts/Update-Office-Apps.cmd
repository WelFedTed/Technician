@echo off

title Update Office Apps

rem Runs _Data\Scripts\update-office-apps.cmd from the drive this launcher is on
start "" "%~d0\_Data\Scripts\update-office-apps.cmd"
exit /b
