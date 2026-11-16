@echo off

title Updating Router IP and Passwords

rem Router IP and Passwords is a website (routerpasswords.com): each brand's page lists its routers' default login
rem address (eg. 192.168.0.1) and their default username and password, so there's nothing to download. run.cmd
rem opens it in the browser.
rem This update.cmd is here so Update-Tool.cmd and run.cmd (the drive's app launcher) list it like the other apps.

echo Router IP and Passwords is a website ^(https://www.routerpasswords.com/^), so there's nothing to download.

if /i not "%~1" == "/nopause" pause
exit /b 0