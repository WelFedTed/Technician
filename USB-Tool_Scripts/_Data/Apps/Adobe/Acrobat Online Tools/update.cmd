@echo off

title Updating Adobe Acrobat Online Tools

rem Acrobat Online Tools is a website: its tools (PDF to Word, compress, merge, sign, ...) run on Adobe's servers,
rem so there's no offline copy to keep and nothing to download. run.cmd opens it in the browser.
rem This update.cmd is here so Update-Tool.cmd and run.cmd (the drive's app launcher) list it like the other apps.

echo Adobe Acrobat Online Tools is a website ^(https://www.adobe.com/au/acrobat/online.html^), so there's nothing to download.

if /i not "%~1" == "/nopause" pause
exit /b 0
