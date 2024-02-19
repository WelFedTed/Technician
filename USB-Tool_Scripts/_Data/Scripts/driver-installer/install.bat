REM Checks if running as Admin, then passes the directory to "Install-WindowsDriverFromFolder.ps1"
REM Run from folder with drivers in it

@echo off

    echo Checking if you have Administrator permissions...

    net session >nul 2>&1
    if %errorLevel% == 0 (
        echo You have Administrator permissions, installing drivers...
pushd "%~dp0"
PowerShell.exe -Command "& {Start-Process PowerShell.exe -ArgumentList '-NonInteractive -NoProfile -ExecutionPolicy Bypass -File "%~dp0\Install-WindowsDriversFromFolder.ps1 %~dp0"' -Verb RunAs}"
echo Installation Complete
exit
    ) else (
        echo Failure: Administrator permission is required to install. Please right click Install.bat and Select Run as Administrator... 
    )

    pause >nul