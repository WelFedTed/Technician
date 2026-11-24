@echo off
setlocal enableextensions disabledelayedexpansion

title Copy File By EXT

rem Copies every document-type file (Office, PDF, text, ...) found in a folder and its subfolders into one folder
rem per extension (eg. ...\docx, ...\pdf), eg. to pick a customer's documents out of a copy of their old drive
rem Usage: batch-backup-ext.cmd [source folder] [destination folder]
rem   source:      asked for if not given (default C:\Temp)
rem   destination: asked for if not given (default: a new folder in the Backups folder in the root of the USB tool,
rem                eg. Z:\Backups\Files-By-Extension_PC-NAME_2026-11-24_1530)
rem Files with the same name are kept as "name (2).ext", "name (3).ext", ...
rem (Delayed Expansion is off, so file names with ! in them are copied as they are)

set "extensions=csv doc docm docx dot dotm dotx md odp ods odt pdf pot potm potx ppa ppam pps ppsm ppsx ppt pptm pptx rtf txt wps xla xlam xls xlsb xlsm xlsx xlt xltm xltx xlw xml xps"
rem testing file extensions set
rem set "extensions=md pdf txt xml"

rem the folder to copy from
set "source=%~1"
if not "%source%" == "" goto gotSource
set "source=C:\Temp"
set /p "source=Folder to copy the files from [C:\Temp]: "
set "source=%source:"=%"
:gotSource
for %%P in ("%source%") do set "source=%%~fP"
if "%source:~-1%" == "\" set "source=%source:~0,-1%"
if not exist "%source%\" (
	echo Couldn't find the folder "%source%".
	pause
	exit /b 1
)

rem the folder to copy to: the Backups folder in the root of the USB tool (this script is in _Data\Scripts)
for %%R in ("%~dp0..\..") do set "toolRoot=%%~fR"
if "%toolRoot:~-1%" == "\" set "toolRoot=%toolRoot:~0,-1%"
set "stamp="
for /f %%D in ('powershell -NoProfile -Command "Get-Date -Format yyyy-MM-dd_HHmm" 2^>nul') do set "stamp=%%D"
if not defined stamp set "stamp=%RANDOM%"
set "dest=%~2"
if not "%dest%" == "" goto gotDest
set "dest=%toolRoot%\Backups\Files-By-Extension_%COMPUTERNAME%_%stamp%"
echo:
echo The files will be copied to:
echo   "%dest%"
set /p "dest=Press Enter to use that folder, or type another: "
set "dest=%dest:"=%"
:gotDest
for %%P in ("%dest%") do set "dest=%%~fP"
if "%dest:~-1%" == "\" set "dest=%dest:~0,-1%"

rem (not into the folder being copied from: the copies would be found and copied again)
set "inside=0"
for /f %%I in ('powershell -NoProfile -Command "if (($env:dest + '\').StartsWith($env:source + '\', 'OrdinalIgnoreCase')) { 'yes' }" 2^>nul') do set "inside=1"
if "%inside%" == "1" (
	echo The destination can't be inside the folder being copied from.
	pause
	exit /b 1
)
if not exist "%dest%\" mkdir "%dest%"
if not exist "%dest%\" (
	echo Couldn't make the folder "%dest%".
	pause
	exit /b 1
)

echo:
echo Copying all files with desired file extensions...
echo   from: "%source%"
echo   to:   "%dest%"
echo:

set /a copied=0
rem (*.ext also matches files whose short 8.3 name has that extension, eg. *.doc finds report.docx, whose short
rem  name is REPORT~1.DOC; so only files whose real extension is the one being copied are copied)
for %%e in (%extensions%) do (
	echo Processing files with extension: .%%e
	echo ----------------------------------------------------------------------------------------------------
	for /r "%source%" %%f in (*.%%e) do if /i "%%~xf" == ".%%e" (
		set "file=%%~ff"
		set "ext=%%e"
		call :copyOne
	)
	echo:
)

echo Removing empty directories...
rem (the extension folders nothing was found for)
for /d %%d in ("%dest%\*") do rmdir "%%~fd" 2>nul

echo:
echo ----------------------------------------------------------------------------------------------------
echo %copied% file(s) copied to:
echo   "%dest%"
echo End of script
pause
exit /b


rem copies %file% into its extension's folder (%dest%\%ext%), adding " (2)", " (3)", ... to its name if that
rem folder already has a file with its name
:copyOne
if not exist "%dest%\%ext%\" mkdir "%dest%\%ext%"
for %%A in ("%file%") do (
	set "name=%%~nA"
	set "fileExt=%%~xA"
)
set "target=%dest%\%ext%\%name%%fileExt%"
set /a n=1
:copyOneNext
if not exist "%target%" goto copyOneGo
set /a n+=1
set "target=%dest%\%ext%\%name% (%n%)%fileExt%"
goto copyOneNext
:copyOneGo
echo Copying "%file%"
copy /y "%file%" "%target%" >nul
if errorlevel 1 (
	echo   Couldn't copy it.
	exit /b 0
)
set /a copied+=1
exit /b 0
