@echo off

REM Updated: 19-09-2019

REM https://help.ea.com/en-us/help/faq/clear-cache-to-fix-problems-with-your-games/

title Fix Origin Client

set processA=Origin.exe
set processB=OriginWebHelperService.exe
set tempFolder=_fixOrigin_localContent

echo Ending %processA%...
taskkill /F /IM "%processA%"
echo:
echo Ending %processB%...
taskkill /F /IM "%processB%"
REM echo:
timeout /t 5 /nobreak
echo:
echo Clearing ProgramData Cache...
XCOPY "%PROGRAMDATA%\Origin\LocalContent\*" "%TEMP%\%tempFolder%" /s /i
RD /S /Q "%PROGRAMDATA%\Origin"
XCOPY "%TEMP%\%tempFolder%\*" "%PROGRAMDATA%\Origin\LocalContent" /s /i
RD /S /Q "%TEMP%\%tempFolder%"
echo:
echo Clearing AppData Cache...
RD /S /Q "C:\Users\bucky\AppData\Local\Origin"
echo:
echo Starting Origin...
start "" "C:\Program Files (x86)\Origin\%processA%"
echo:

echo:
PAUSE
exit