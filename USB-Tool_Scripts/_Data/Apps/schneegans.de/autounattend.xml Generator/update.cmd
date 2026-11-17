@echo off

title Updating autounattend.xml Generator

rem The autounattend.xml generator is a website: it builds the file on its own servers from the options you pick, so
rem there's nothing to download. run.cmd opens it in the browser.
rem This update.cmd is here so Update-Tool.cmd and run.cmd (the drive's app launcher) list it like the other apps.

echo The autounattend.xml generator is a website ^(https://schneegans.de/windows/unattend-generator/^), so there's nothing to download.

if /i not "%~1" == "/nopause" pause
exit /b 0