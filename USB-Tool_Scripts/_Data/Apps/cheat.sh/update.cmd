@echo off

title Updating cheat.sh

rem cheat.sh is a website: its cheat sheets are looked up on its own servers, so there's nothing to download. cli.cmd opens a prompt that looks them up.
rem This update.cmd is here so Update-Tool.cmd and run.cmd (the drive's app launcher) list it like the other apps.

echo cheat.sh is a website ^(https://cheat.sh/^), so there's nothing to download.

if /i not "%~1" == "/nopause" pause
exit /b 0