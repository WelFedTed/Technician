@echo off

title Copy File By EXT

set "source=C:\Temp"

rem robocopy  %source% .\csv *.csv
rem robocopy  %source% .\doc *.doc
rem robocopy  %source% .\docm *.docm
rem robocopy  %source% .\docx *.docx
rem robocopy  %source% .\dot *.dot
rem robocopy  %source% .\dotm *.dotm
rem robocopy  %source% .\dotx *.dotx
rem robocopy  %source% .\odp *.odp
rem robocopy  %source% .\ods *.ods
rem robocopy  %source% .\odt *.odt
rem robocopy  %source% .\pdf *.pdf
rem robocopy  %source% .\pot *.pot
rem robocopy  %source% .\potm *.potm
rem robocopy  %source% .\potx *.potx
rem robocopy  %source% .\ppa *.ppa
rem robocopy  %source% .\ppam *.ppam
rem robocopy  %source% .\pps *.pps
rem robocopy  %source% .\ppsm *.ppsm
rem robocopy  %source% .\ppsx *.ppsx
rem robocopy  %source% .\ppt *.ppt
rem robocopy  %source% .\pptm *.pptm
rem robocopy  %source% .\pptx *.pptx
rem robocopy  %source% .\rtf *.rtf
rem robocopy  %source% .\wps *.wps
rem robocopy  %source% .\xla *.wla
rem robocopy  %source% .\xlam *.xlam
rem robocopy  %source% .\xls *.slx
rem robocopy  %source% .\xlsb *.xlsb
rem robocopy  %source% .\xlsm *.xlsm
rem robocopy  %source% .\xlsx *.xlsx
rem robocopy  %source% .\xltm *.xltm
rem robocopy  %source% .\xlt *.xlt
rem robocopy  %source% .\xltx *.xltx
rem robocopy  %source% .\xlw *.xlw
rem robocopy  %source% .\xml *.xml
rem robocopy  %source% .\xps *.xps

set "extensions=csv doc docm docx dot dotm dotx md odp ods odt pdf pot potm potx ppa ppam pps ppsm ppsx ppt pptm pptx rtf txt wps xla xlam xls xlsb xlsm xlsx xlt xltm xltx xlw xml xps"
set "extensions=md pdf txt xml"

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
