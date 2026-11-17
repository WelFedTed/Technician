@echo off

title autounattend.xml Generator

rem Opens Christoph Schneegans' autounattend.xml generator in the default browser (a website, so it needs the internet).
rem It makes an answer file for unattended Windows 10/11 installs: skip the Microsoft account and online
rem sign-in, set the language, user accounts and time zone, remove preinstalled apps, bypass the Windows 11
rem requirements check, and more. Save the file as autounattend.xml in the root of the Windows install USB.

echo Opening the autounattend.xml generator...
start "" "https://schneegans.de/windows/unattend-generator/"
exit /b