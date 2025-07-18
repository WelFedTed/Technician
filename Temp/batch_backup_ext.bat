@echo off

title Copy File By EXT

set "source=C:\Temp"

echo Copying all files with desired file extensions...
echo:

set "extensions=csv doc docm docx dot dotm dotx md odp ods odt pdf pot potm potx ppa ppam pps ppsm ppsx ppt pptm pptx rtf txt wps xla xlam xls xlsb xlsm xlsx xlt xltm xltx xlw xml xps"
rem testing file extensions set
rem set "extensions=md pdf txt xml"

for %%e in (%extensions%) do (
    echo Processing files with extension: .%%e
    echo ----------------------------------------------------------------------------------------------------
    mkdir ".\%%e" 2>nul
    for /r "%source%" %%f in (*.%%e) do (
        echo Copying "%%f" to ".\%%e"
        copy "%%f" ".\%%e"
    )
    echo:
)

echo Removing empty directories...
for /d /r %%d in (*) do (
	dir /b %%d | findstr . >nul
	if errorlevel 1 (
	    rem echo %%d Folder is empty.
	    rmdir %%d
	) else (
	    rem echo %%d Folder is NOT empty.
	)
)

echo:
echo ----------------------------------------------------------------------------------------------------
echo End of script
pause
