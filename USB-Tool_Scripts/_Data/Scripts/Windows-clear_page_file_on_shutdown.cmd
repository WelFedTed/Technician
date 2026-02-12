@echo off

REM Updated: 03-02-2021

REM Configures Windows to clear the Page File at Shut Down

reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v ClearPageFileAtShutdown /t REG_DWORD /d 1 /f