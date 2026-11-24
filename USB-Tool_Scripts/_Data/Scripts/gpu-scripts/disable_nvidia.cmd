@echo off
:: Check for administrative rights
:: (fltmc only succeeds as administrator; unlike net session it doesn't depend on the Server service,
:: which isn't running in WinPE or when it's been stopped, and made the elevated copy relaunch itself over and over)
fltmc >nul 2>&1
if %errorLevel% neq 0 (
    echo Requesting administrative privileges...
    goto UACPrompt
) else ( goto gotAdmin )

:UACPrompt
    echo Set UAC = CreateObject^("Shell.Application"^) > "%temp%\getadmin.vbs"
    echo UAC.ShellExecute "%~s0", "", "", "runas", 1 >> "%temp%\getadmin.vbs"
    "%temp%\getadmin.vbs"
    del "%temp%\getadmin.vbs"
    exit /B

:gotAdmin
:: --- CONFIGURATION ---
:: Replace the text inside the quotes with your actual GPU Device Instance ID
set "GPU_ID=PCI\VEN_10DE&DEV_1C81&SUBSYS_11C010DE&REV_A1\4&2db3ecda&0&0008"
:: ---------------------

echo Disabling GPU...
pnputil /disable-device "%GPU_ID%"

echo Done.
pause
