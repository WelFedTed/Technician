@echo off

title Ninite

rem Opens Ninite in the default browser: tick the apps to install (browsers, 7-Zip, VLC, Zoom, ...) and it makes one
rem installer that installs them all at once, with no toolbars or extra offers, and gets their latest versions as it
rem runs (so it needs the internet). Running the same installer again later updates those apps.

echo Opening Ninite...
start "" "https://ninite.com/"
exit /b