@echo off

title EIZO Monitor Test

rem EIZO's monitor test runs in the browser (test patterns for defective pixels, uniformity, colours, gradients,
rem sharpness, viewing angle, gamma and response time). update.cmd copies it to Portable\Any so it works offline;
rem until it has, this opens it on EIZO's site instead.
rem Pick the tests and press "Start test": it goes full screen (Esc ends it).

set "page=%~dp0Portable\Any\index.html"
if exist "%page%" (
	echo Opening EIZO's monitor test from the USB...
	start "" "%page%"
) else (
	echo The offline copy isn't on the USB yet ^(Update-Tool.cmd downloads it^), so opening it on EIZO's site...
	start "" "https://www.eizo.be/monitor-test/"
)
exit /b
