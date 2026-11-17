@echo off

title Updating MyASUS

rem MyASUS only comes from the Microsoft Store, which keeps it up to date, so there's nothing to download.
rem install.cmd opens it in the Store. This update.cmd is here so Update-Tool.cmd and run.cmd (the drive's app
rem launcher) list it like the other apps.

echo MyASUS comes from the Microsoft Store ^(install.cmd opens it there^), so there's nothing to download.

if /i not "%~1" == "/nopause" pause
exit /b 0