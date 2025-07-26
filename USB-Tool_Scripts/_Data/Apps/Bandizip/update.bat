@echo off

title App Updater

echo Bandizip
echo ----------------------------------------------------------------------------------------------------

set "download=https://en.bandisoft.com/bandizip/dl.php?web"
set "update=update.tmp"
set "app=BANDIZIP-SETUP-STD-ALL.EXE"

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
par2 c -v -b5000 -r5 -n1 -R parity.par2 *

echo:
echo End of script
rem pause
exit /b