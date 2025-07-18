@echo off

title Copy File By EXT

set "source=C:\Temp"

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


echo:
echo End of script
pause
