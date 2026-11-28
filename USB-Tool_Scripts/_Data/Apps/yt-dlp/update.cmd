@echo off

title Updating yt-dlp

rem Updates this app with the shared helper _Data\Apps\_Update-App.ps1 (see that file for the options)
rem Run it on its own, or let Update-Tool.cmd run it for every app
rem Each kind of download has its own folder here: Installer (install.cmd), Portable (run.cmd), CLI (cli.cmd)

rem clear PSModulePath so Windows PowerShell loads its own modules (it breaks if started from PowerShell 7)
set "PSModulePath="
set "result=0"
set "resultRank=0"

rem CLI (yt-dlp.exe for 64-bit, 32-bit and ARM64 Windows, each saved as yt-dlp.exe so the same command works on
rem every PC. To merge video and audio, or convert, it needs FFmpeg: the USB has it in
rem _Data\Apps\FFmpeg\CLI\x64\bin, so add --ffmpeg-location "<that folder>" or put ffmpeg.exe on the PATH)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_Update-App.ps1" -AppDir "%~dp0CLI" ^
    -Name "yt-dlp" ^
    -Page "https://github.com/yt-dlp/yt-dlp/releases/latest" ^
    -GitHub "yt-dlp/yt-dlp" ^
    -Asset "^yt-dlp\.exe$" -Into "x64" ^
    -Asset86 "^yt-dlp_x86\.exe$" -Into86 "x86" -SaveAs86 "yt-dlp.exe" ^
    -AssetArm "^yt-dlp_arm64\.exe$" -IntoArm "ARM64" -SaveAsArm "yt-dlp.exe" ^
    -Clean ^
    -MajorGeeks "yt_dlp:64-Bit" -MajorGeeks86 "yt_dlp:32-Bit"
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
