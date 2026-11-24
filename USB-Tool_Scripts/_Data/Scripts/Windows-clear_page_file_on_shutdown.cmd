@echo off

REM Updated: 03-02-2021

REM Configures Windows to clear the Page File at Shut Down

REM it changes HKEY_LOCAL_MACHINE, so it needs to run as admin: if it isn't, start again as admin
REM (cmd.exe is started itself, with the whole command in an extra pair of quotes, as Windows' own Run as
REM  administrator for scripts loses the quotes around a path with & in it)
fltmc >nul 2>&1
if errorlevel 1 (
	set "self=%~f0"
	powershell -NoProfile -Command "$q = [char]34; Start-Process -FilePath ($env:SystemRoot + '\System32\cmd.exe') -ArgumentList ('/d /c ' + $q + $q + $env:self + $q + $q) -Verb RunAs"
	exit /b
)

reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v ClearPageFileAtShutdown /t REG_DWORD /d 1 /f
pause