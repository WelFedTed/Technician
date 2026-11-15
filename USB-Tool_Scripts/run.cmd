@echo off
setlocal EnableExtensions DisableDelayedExpansion

title Run an app

rem Notes
rem ----------------------------------------------------------------------------------------------------
	rem Lists every app in _Data\Apps to search with fzf: type part of a name (letters in order are enough, eg.
	rem "wnmrg" for WinMerge), move with the arrow keys or the mouse, Enter starts it, Esc closes without starting
	rem anything
	rem The app is started with its own launcher, the first it has of: run.cmd (the portable app), install.cmd
	rem (its installer), cli.cmd (a command prompt with its command-line tools)
	rem fzf is kept on the USB like the other apps (_Data\Apps\fzf, updated by Update-Tool.cmd). Without it (before
	rem Update-Tool has downloaded it, or on 32-bit Windows, which fzf doesn't support), this asks for part of the
	rem name instead and lists the matches by number
	rem Usage: run.cmd [search]   eg. "run.cmd 7zip" starts with 7zip already typed in
	rem It finds _Data next to itself, so the USB tool works from a drive's root (eg. Z:\run.cmd) or from any folder (eg. a copy in D:\Tools\USB-Tool)
	rem (delayed expansion is off, so app names with ! in them are kept as they are)


rem Settings
rem ----------------------------------------------------------------------------------------------------
	set "apps=%~dp0_Data\Apps"
	rem the search typed after run.cmd, word by word without quotes (%* would keep the quotes of eg. run.cmd "o&o",
	rem leaving the & outside them)
	set "query="
	:nextWord
	if "%~1" == "" goto gotQuery
	if defined query ( set "query=%query% %~1" ) else ( set "query=%~1" )
	shift
	goto nextWord
	:gotQuery
	set "list=%TEMP%\USB-Tool-run-%RANDOM%%RANDOM%.txt"
	set "pick=%list%.pick"
	set "selected="


rem The Apps
rem ----------------------------------------------------------------------------------------------------
	if not exist "%apps%\" (
		echo Couldn't find "%apps%"
		pause
		exit /b 1
	)
	rem the app folders with a launcher (folders starting with _ are notes, not apps), one per line in a file,
	rem so names with & or ( ) in them are never read as commands
	type nul > "%list%"
	for /f "delims=" %%D in ('dir /b /ad /on "%apps%" ^| findstr /v /b "_"') do (
		set "launcher="
		if exist "%apps%\%%D\run.cmd" set "launcher=1"
		if exist "%apps%\%%D\install.cmd" set "launcher=1"
		if exist "%apps%\%%D\cli.cmd" set "launcher=1"
		if defined launcher >>"%list%" echo(%%D
	)


rem Pick One
rem ----------------------------------------------------------------------------------------------------
	rem fzf's build for this PC (ARM64 Windows also runs x64 builds; there's no 32-bit build)
	set "arch=x86"
	if /i "%PROCESSOR_ARCHITECTURE%" == "AMD64" set "arch=x64"
	if /i "%PROCESSOR_ARCHITEW6432%" == "AMD64" set "arch=x64"
	if /i "%PROCESSOR_ARCHITECTURE%" == "ARM64" set "arch=ARM64"
	if /i "%PROCESSOR_ARCHITEW6432%" == "ARM64" set "arch=ARM64"
	set "fzf="
	if "%arch%" == "ARM64" if exist "%apps%\fzf\CLI\ARM64\fzf.exe" set "fzf=%apps%\fzf\CLI\ARM64\fzf.exe"
	if not defined fzf if not "%arch%" == "x86" if exist "%apps%\fzf\CLI\x64\fzf.exe" set "fzf=%apps%\fzf\CLI\x64\fzf.exe"
	if not defined fzf goto noFzf

	rem (fzf draws in the window itself; only the chosen name goes to the file. Esc leaves it empty)
	"%fzf%" --prompt="Run app > " --header="Type to search, Enter starts it, Esc closes" --layout=reverse --info=inline --query="%query%" < "%list%" > "%pick%"
	if exist "%pick%" set /p selected=<"%pick%"
	goto launch

	:noFzf
	echo fzf isn't on this USB yet ^(Update-Tool.cmd downloads it^), or can't run on this PC, so search by name instead.
	echo:
	if not defined query set /p "query=Type part of the app's name (or just press Enter for all of them): "
	rem matching names, numbered by their line in the list (as typed, or else without its spaces, so eg.
	rem "crystal disk" finds CrystalDiskInfo)
	if defined query set "squeezed=%query: =%"
	if defined query (
		findstr /n /i /l /c:"%query%" "%list%" || findstr /n /i /l /c:"%squeezed%" "%list%"
	) else (
		findstr /n "^" "%list%"
	)
	if errorlevel 1 (
		echo No app's name has "%query%" in it.
		pause
		goto cleanUp
	)
	echo:
	set "number="
	set /p "number=Type the app's number and press Enter (or just Enter to close): "
	if not defined number goto cleanUp
	for /f "tokens=1* delims=:" %%A in ('findstr /n "^" "%list%"') do if "%%A" == "%number%" set "selected=%%B"
	if not defined selected (
		echo There's no app number %number%.
		pause
		goto cleanUp
	)


rem Start It
rem ----------------------------------------------------------------------------------------------------
:launch
	if not defined selected goto cleanUp
	set "script="
	for %%S in (run.cmd install.cmd cli.cmd) do (
		if not defined script if exist "%apps%\%selected%\%%S" set "script=%apps%\%selected%\%%S"
	)
	if not defined script (
		setlocal EnableDelayedExpansion
		echo Couldn't find a launcher for "!selected!".
		endlocal
		pause
		goto cleanUp
	)
	del /q "%list%" "%pick%" 2>nul
	rem (the name through delayed expansion, so & or ( ) in it, eg. "O&O ShutUp10++", aren't read as commands)
	setlocal EnableDelayedExpansion
	title !selected!
	echo Starting !selected!...
	endlocal
	call "%script%"
	exit /b

:cleanUp
	del /q "%list%" "%pick%" 2>nul
	exit /b
