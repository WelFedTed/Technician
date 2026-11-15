@echo off
setlocal

title Mole command line

rem Opens a command prompt where "mole" and "mo" run Mole (Windows clean-up, uninstall, disk and system tools)
rem Mole is a PowerShell script, so small mole.cmd and mo.cmd files that run it are made in %TEMP% and put on
rem the PATH, as Mole's own installer does. Arguments given to this script are run straight away,
rem eg. cli.cmd clean --dry-run

set "mole=%~dp0CLI\x64\mole.ps1"
if not exist "%mole%" (
	echo Couldn't find "%mole%"
	echo Run Update-Tool.cmd to download it, or check the app's folder.
	pause
	exit /b 1
)

rem Mole's tools are 64-bit (ARM64 Windows runs them too)
set "arch=x86"
if /i "%PROCESSOR_ARCHITECTURE%" == "AMD64" set "arch=x64"
if /i "%PROCESSOR_ARCHITEW6432%" == "AMD64" set "arch=x64"
if /i "%PROCESSOR_ARCHITECTURE%" == "ARM64" set "arch=ARM64"
if /i "%PROCESSOR_ARCHITEW6432%" == "ARM64" set "arch=ARM64"
if "%arch%" == "x86" (
	echo Mole only has a 64-bit build, so it can't run on this 32-bit PC.
	pause
	exit /b 1
)

set "shim=%TEMP%\USB-Tool-Mole"
if not exist "%shim%\" mkdir "%shim%"
> "%shim%\mole.cmd" echo @powershell -NoProfile -ExecutionPolicy Bypass -File "%mole%" %%*
copy /y "%shim%\mole.cmd" "%shim%\mo.cmd" >nul
set "PATH=%shim%;%PATH%"

cd /d "%USERPROFILE%"
echo:
echo Type "mole" (or "mo") to use Mole, eg. "mole clean --dry-run" to see what it would clean,
echo or "exit" to close this prompt.
echo:
if not "%~1" == "" (
	cmd /k mole %*
	exit /b
)
cmd /k mole --help
exit /b
