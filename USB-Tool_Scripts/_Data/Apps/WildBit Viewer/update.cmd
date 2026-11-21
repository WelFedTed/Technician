@echo off

title Updating WildBit Viewer

rem Updates this app with the shared helper _Data\Apps\_Update-App.ps1 (see that file for the options)
rem Run it on its own, or let Update-Tool.cmd run it for every app
rem Each kind of download has its own folder here: Installer (install.cmd), Portable (run.cmd), CLI (cli.cmd)

rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
set "result=0"
set "resultRank=0"

rem WildBit Viewer (WildBit Software's image viewer, slide show, editor and search) has reached end-of-life: 6.20.1
rem (June 2026) is its final version, and the maker removed its downloads on 31 July 2026
rem (https://www.wildbit-soft.fi/roadmap.html). So these come from the Internet Archive's copies of the maker's own
rem 6.20.1 links (wildbit-soft.fi/download/dev/6_20_1/...); its 32-bit setup is the same file as MajorGeeks' copy.
rem Each must have the SHA256 the maker published for it (wildbit-soft.fi/hashes.html, as the Internet Archive saved
rem it on 7 July 2026), or it isn't used (-Hash / -Hash86). Checked 22 Nov 2026: all four match, Defender finds
rem nothing, VirusTotal shows the zips clean (0/66) and the setups flagged only by Gridinsoft's generic
rem "Downloader" (1/58 and 1/70), and the maker's exes are unsigned (as they always were).

rem Installer (32-bit and 64-bit setups. MajorGeeks is the backup for the 32-bit one only: both its download
rem buttons give the 32-bit ViewerSetup.exe)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0Installer" ^
    -Name "WildBit Viewer (installer)" ^
    -Page "https://www.wildbit-soft.fi/software.html" ^
    -Url "https://web.archive.org/web/20260627110754id_/https://wildbit-soft.fi/download/dev/6_20_1/ViewerSetup_x64.exe" -Into "x64" ^
    -Url86 "https://web.archive.org/web/20260707230619id_/https://wildbit-soft.fi/download/dev/6_20_1/ViewerSetup.exe" -Into86 "x86" ^
    -Hash "FBF4F32FD7B9B29432D2D78C28E753323C07980D4B303E3188608E42F27E0CA8" ^
    -Hash86 "6B302E2A523E303AF9E31398A2514A08849969647DC9136ABA441365407146AE" ^
    -Clean ^
    -MajorGeeks86 "wildbit_viewer"
call :result

rem Portable (the maker's portable zips, unpacked here. run.cmd starts bin\Viewer.exe with /portable, as the zip's
rem own Viewer.cmd does, which syncs its settings between that bin folder and the PC's AppData; the Slide Show,
rem Editor and Search tools are next to it there)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0Portable" ^
    -Name "WildBit Viewer (portable)" ^
    -Page "https://www.wildbit-soft.fi/software.html" ^
    -Url "https://web.archive.org/web/20260627111107id_/https://wildbit-soft.fi/download/dev/6_20_1/Viewerportable_x64.zip" -Into "x64" ^
    -Url86 "https://web.archive.org/web/20260707230803id_/https://wildbit-soft.fi/download/dev/6_20_1/Viewerportable.zip" -Into86 "x86" ^
    -Hash "AE20E86D4E4EB8C61BF01F6E84ED8ADBB1B61F4BC00E2102942B95C83EDF0A0B" ^
    -Hash86 "6118F39FC6CAB7BACA6C9E17C42968F50D0DDB2A0F45006A24F5C58E017CE278" ^
    -Extract -Flatten -Clean ^
    -VersionFrom "x64\bin\Viewer.exe"
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
