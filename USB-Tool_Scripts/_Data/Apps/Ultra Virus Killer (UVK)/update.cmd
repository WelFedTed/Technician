@echo off

title App Updater

echo Ultra Virus Killer (UVK)
echo ----------------------------------------------------------------------------------------------------

set "download=https://www.carifred.com/uvk/UVKPortable.exe"
set "update=update.tmp"
set "app=UVKPortable.exe"

echo:
echo Checking for WGet...
where wget >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo WGet is installed and available in the PATH.
    echo Proceeding with update...
) else (
    echo WGet is not installed or not in the PATH.
    echo Attempting to install WGet using winget...
    goto INSTALL-WGET
)
:PROCEED

echo:
echo Downloading 7zip (required for update)...
wget https://www.7-zip.org/a/7zr.exe -P %TEMP%
set "zip=%TEMP%\7zr.exe"

echo:
echo Downloading update...
del %update%
wget %download% -O %update%

echo:
echo Applying update...
del %app%
ren %update% %app%

echo:
echo Updating version file...
del *.version
for /f "usebackq tokens=*" %%i in (`powershell -command "$version = (Get-Item '%app%').VersionInfo.FileVersionRaw; $version -replace '\s+', '.'"`) do set "version=%%i"
for /f "usebackq tokens=*" %%i in (`powershell -command "(Get-Item '%app%').LastWriteTime.ToString('yyyy-MM-dd')"`) do set "date=%%i"
type NUL > v%version%_%date%.version

echo:
echo Updating checksums...
del checksums.sfv
del *.par2
set "hashutils=hashutils-1.2.4-redist"
wget https://code.kliu.org/misc/hashutils/%hashutils%.7z -P %TEMP%
%zip% x %TEMP%\%hashutils%.7z -o%TEMP%\%hashutils% -aoa
%TEMP%\%hashutils%\bin.x86-64\crc32sum.exe -r * > checksums.sfv
findstr /v checksums.sfv checksums.sfv > checksums.sfv.tmp
del checksums.sfv
ren checksums.sfv.tmp checksums.sfv

echo:
echo Updating parity data...
set "par2ver=1.0.0"
wget https://github.com/Parchive/par2cmdline/releases/download/v%par2ver%/par2cmdline-%par2ver%-win-x64.zip -P %TEMP%
tar -xf %TEMP%\par2cmdline-%par2ver%-win-x64.zip -C %TEMP%
%TEMP%\par2.exe c -v -b5000 -r5 -n1 -R parity.par2 *

echo:
echo End of script
rem pause
exit /b

@REM --------------------------------------------

:INSTALL-WGET
echo Checking for Winget...
where winget >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo winget is installed and available in the PATH.
) else (
    echo winget is not installed or not in the PATH.
    echo Please install winget and ensure it is in the PATH before running this script
    echo You can try running the following script from powershell to fix/install winget: "irm asheroto.com/winget | iex"
    pause
    exit /b
)
echo Installing WGet...
winget install wget
echo:

echo Refreshing path for current session...
setx /M dummy "%PATH%" >nul 2>&1   :: writes nothing, but triggers a WM_SETTINGCHANGE
for /f "tokens=2*" %%A in ('reg query "HKCU\Environment" /v Path 2^>nul') do set "userPath=%%B"
set "PATH=%userPath%;%PATH%"

goto PROCEED