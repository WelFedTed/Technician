@echo off

title Keyboard Checker

rem Keyboard Checker runs in the browser: press each key, and it turns green on the picture of the keyboard if it
rem works. update.cmd copies it to Portable\Any so it works offline; until it has, this opens the website instead.

set "page=%~dp0Portable\Any\index.html"
if exist "%page%" (
	echo Opening Keyboard Checker from the USB...
	start "" "%page%"
) else (
	echo The offline copy isn't on the USB yet ^(Update-Tool.cmd downloads it^), so opening the website...
	start "" "https://keyboardchecker.com/"
)
exit /b
