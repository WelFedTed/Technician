@echo off
setlocal

title CyberChef

rem Opens CyberChef (GCHQ's "Cyber Swiss Army Knife": encoding, decoding, encryption, compression and data
rem analysis in the browser). update.cmd saves its offline copy in Portable\Any; until it has, this opens it on
rem gchq.github.io instead. Everything runs in the browser, so nothing typed or loaded into it leaves the PC.
set "page="
for /f "delims=" %%F in ('dir /b /o:n "%~dp0Portable\Any\CyberChef_v*.html" 2^>nul') do set "page=%~dp0Portable\Any\%%F"
if defined page (
	echo Opening CyberChef from the USB...
	start "" "%page%"
) else (
	echo The offline copy isn't on the USB yet ^(Update-Tool.cmd downloads it^), so opening it on gchq.github.io...
	start "" "https://gchq.github.io/CyberChef/"
)
exit /b