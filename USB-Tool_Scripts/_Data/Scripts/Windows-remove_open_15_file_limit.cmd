@echo off

REM Updated: 03-11-2018

REM Increase Windows Explorer context menu threshold for opening files

reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer" /v MultipleInvokePromptMinimum /t REG_DWORD /d 500 /f