@echo off

title BIOS Master Password Generator

rem Makes the master password that unlocks a laptop's BIOS (or hard drive) password from the code the laptop
rem shows after too many wrong tries (Dell, HP, Acer, Fujitsu, Sony, Samsung, Lenovo...). update.cmd copies bios-pw.org
rem to Portable\Any so it works offline; until it has, this opens it on bios-pw.org instead.
set "page=%~dp0Portable\Any\index.html"
if exist "%page%" (
	echo Opening the BIOS master password generator from the USB...
	start "" "%page%"
) else (
	echo The offline copy isn't on the USB yet ^(Update-Tool.cmd downloads it^), so opening it on bios-pw.org...
	start "" "https://bios-pw.org/"
)
exit /b
