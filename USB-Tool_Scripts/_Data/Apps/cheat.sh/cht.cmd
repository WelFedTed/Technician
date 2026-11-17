@echo off
rem cht <topic>: looks the topic up on cheat.sh (spaces become +, eg. "cht python reverse list")
setlocal
set "q=%*"
if not defined q set "q=:help"
set "q=%q: =+%"
curl.exe -s "https://cheat.sh/%q%"