@echo off

title Updating Ninite

rem Ninite is a website: its installer is made on its site for the apps you pick, and gets their latest versions as it runs, so there's nothing to download. run.cmd opens it in the browser.
rem This update.cmd is here so Update-Tool.cmd and run.cmd (the drive's app launcher) list it like the other apps.

echo Ninite is a website ^(https://ninite.com/^), so there's nothing to download.

if /i not "%~1" == "/nopause" pause
exit /b 0