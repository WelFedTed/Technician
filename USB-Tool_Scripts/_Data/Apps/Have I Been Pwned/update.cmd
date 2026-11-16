@echo off

title Updating Have I Been Pwned

rem Have I Been Pwned is a website: it searches the breach data on its own servers, so there's nothing to download. run.cmd opens it in the browser.
rem This update.cmd is here so Update-Tool.cmd and run.cmd (the drive's app launcher) list it like the other apps.

echo Have I Been Pwned is a website ^(https://haveibeenpwned.com/^), so there's nothing to download.

if /i not "%~1" == "/nopause" pause
exit /b 0