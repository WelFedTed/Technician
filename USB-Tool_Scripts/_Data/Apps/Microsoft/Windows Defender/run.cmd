@echo off
setlocal

title Windows Security

rem Opens Windows Security (Microsoft Defender) on this PC: it's part of Windows, so there's nothing to run from
rem the USB. install.cmd updates Defender's definitions offline, from the package update.cmd keeps here.
echo Opening Windows Security...
start "" "windowsdefender:"
exit /b