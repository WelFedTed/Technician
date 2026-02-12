@echo off

title App Updater

echo HitmanPro
echo ----------------------------------------------------------------------------------------------------

set "download64=https://download.sophos.com/endpoint/clients/HitmanPro_x64.exe"
set "download86=https://download.sophos.com/endpoint/clients/HitmanPro.exe"
set "update64=update64.tmp"
set "update86=update86.tmp"
set "app64=HitmanPro_x64.exe"
set "app86=HitmanPro.exe"

echo:
echo Downloading 7zip (required for update)...
wget https://www.7-zip.org/a/7zr.exe -P %TEMP%
set "zip=%TEMP%\7zr.exe"

echo:
echo Downloading updates...
del %update64%
wget %download64% -O %update64%
del %update86%
wget %download86% -O %update86%

echo:
echo Applying updates...
del %app64%
ren %update64% %app64%
del %app86%
ren %update86% %app86%

echo:
echo Updating version file...
del *.version
for /f "usebackq tokens=*" %%i in (`powershell -command "$version = (Get-Item '%app64%').VersionInfo.FileVersionRaw; $version -replace '\s+', '.'"`) do set "version=%%i"
for /f "usebackq tokens=*" %%i in (`powershell -command "(Get-Item '%app64%').LastWriteTime.ToString('yyyy-MM-dd')"`) do set "date=%%i"
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