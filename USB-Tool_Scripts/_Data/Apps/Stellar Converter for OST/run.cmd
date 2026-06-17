@echo off
setlocal

set "SOURCE_DIR=%~dp0x64"
set "DEST_DIR=%TEMP%\Stellar Converter for OST"

if exist "%DEST_DIR%" rmdir /s /q "%DEST_DIR%"

robocopy "%SOURCE_DIR%" "%DEST_DIR%" /E
if %ERRORLEVEL% GEQ 8 (
    echo Copy failed.
    exit /b 1
)

start "" "%DEST_DIR%\StellarPhoenixOutlookPstRepair.exe"

endlocal