@echo off

title Updating Apache OpenOffice

rem Updates this app with the shared helper _Data\Apps\_Update-App.ps1 (see that file for the options)
rem Run it on its own, or let Update-Tool.cmd run it for every app
rem Each kind of download has its own folder here: Installer (install.cmd), Portable (run.cmd), CLI (cli.cmd)

rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
set "result=0"
set "resultRank=0"

rem Installer (Apache OpenOffice, the English (US) Windows installer: openoffice.org's download page gets the
rem current version from its globalvars.js, and the files are on Apache's SourceForge mirror, which needs
rem -UserAgent "curl" like the other SourceForge apps here. The setup's own version is a build number (eg.
rem 4.1.9816.500), hence -VersionFromUrl. It's 32-bit only, so it's kept in x86)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0Installer" ^
    -Name "Apache OpenOffice (installer)" ^
    -Page "https://www.openoffice.org/download/globalvars.js" ^
    -Link "DL\.VERSION\s*=\s*\x22([\d.]+)\x22" ^
    -UrlFormat "https://sourceforge.net/projects/openofficeorg.mirror/files/{0}/binaries/en-US/Apache_OpenOffice_{0}_Win_x86_install_en-US.exe/download" ^
    -UserAgent "curl/8.0" -Into "x86" ^
    -VersionFromUrl -Clean ^
    -MajorGeeks "apache_openoffice_org_for_windows"
call :result

rem Portable (PortableApps.com's OpenOffice Portable, Multilingual Standard, unpacked; it can lag behind the
rem installer by a release. Its settings are kept in its Data folder, which an update keeps)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0Portable" ^
    -Name "Apache OpenOffice (portable)" ^
    -Page "https://portableapps.com/apps/office/openoffice_portable" ^
    -Link "f=(OpenOfficePortable_[\d.]+_MultilingualStandard\.paf\.exe)" ^
    -UrlFormat "https://download2.portableapps.com/portableapps/OpenOfficePortable/{0}" -Into "x86" ^
    -Paf
call :result

if /i not "%~1" == "/nopause" pause
exit /b %result%

rem keeps the worst result: failed (1), then needs a manual update (2), then Defender blocked files (3), then OK (0)
:result
set "code=%errorlevel%"
set "rank=3"
if "%code%" == "0" set "rank=0"
if "%code%" == "3" set "rank=1"
if "%code%" == "2" set "rank=2"
if %rank% GTR %resultRank% (
	set "resultRank=%rank%"
	set "result=%code%"
	if %rank% == 3 set "result=1"
)
exit /b 0