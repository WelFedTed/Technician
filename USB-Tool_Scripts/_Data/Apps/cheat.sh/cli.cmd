@echo off

title cheat.sh

rem Opens a command prompt with a "cht" command that looks up cheat sheets on cheat.sh: short, practical
rem examples for command-line tools and programming languages (it's a website, so it needs the internet).
rem Uses curl.exe, which comes with Windows 10 (1803) and later.
rem   cht tar                 the tar command
rem   cht python reverse list a question about a language
rem   cht :list               every sheet it has
rem Any arguments are looked up straight away, eg. cli.cmd robocopy

where curl.exe >nul 2>nul
if errorlevel 1 (
	echo cheat.sh needs curl.exe, which comes with Windows 10 version 1803 and later.
	echo You can open https://cheat.sh/ in a browser instead.
	pause
	exit /b 1
)

rem (cht.cmd, next to this script, does the looking up)
set "PATH=%~dp0;%PATH%"
echo:
echo cheat.sh - cheat sheets for commands and programming languages
echo:
echo   cht tar                   the tar command
echo   cht python reverse list   a question about a language
echo   cht :list                 every sheet it has
echo:
echo Type "exit" to close this prompt.
echo:
if not "%~1" == "" (
	cmd /k "cht.cmd %*"
	exit /b
)
cmd /k
exit /b