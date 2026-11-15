@echo off

title Build Aseprite

rem Builds the latest Aseprite release from source into this app's Portable\x64 folder, so run.cmd can start it
rem Needs Visual Studio 2022 (Community or Build Tools) with "Desktop development with C++" on this PC, and
rem about 5 GB free in %TEMP% (or on the USB, which it uses when C: is too full); see build.ps1 for the
rem details and options (eg. build.cmd -WorkDir D:\Build)

rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0build.ps1" %*
set "result=%errorlevel%"

echo:
pause
exit /b %result%
