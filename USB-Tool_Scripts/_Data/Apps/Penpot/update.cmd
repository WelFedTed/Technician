@echo off

title Updating Penpot

rem Penpot is a website: it runs in the browser (there is no official Windows app), so there's nothing to download. run.cmd opens it in the browser.
rem This update.cmd is here so Update-Tool.cmd and run.cmd (the drive's app launcher) list it like the other apps.

echo Penpot is a website ^(https://design.penpot.app/^), so there's nothing to download.

if /i not "%~1" == "/nopause" pause
exit /b 0