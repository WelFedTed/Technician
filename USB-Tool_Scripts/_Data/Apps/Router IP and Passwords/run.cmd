@echo off

title Router IP and Passwords

rem Opens routerpasswords.com, which lists each router brand's default login address (eg. 192.168.0.1) and
rem default username and password, in the default browser (a website, so it needs the internet)

echo Opening Router IP and Passwords...
start "" "https://www.routerpasswords.com/"
exit /b