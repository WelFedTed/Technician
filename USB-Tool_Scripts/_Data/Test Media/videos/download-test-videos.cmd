@echo off
setlocal

title Downloading Test Videos...

rem Downloads each test video (the .url files next to this script) at every resolution from 144p to 2160p, into
rem this folder, as <name>_<height>p.mp4
rem Needs yt-dlp (https://github.com/yt-dlp/yt-dlp) on the PATH, and FFmpeg to join each video to its sound: the
rem USB's own copy (_Data\Apps\FFmpeg) is used when it's there

cd /d "%~dp0"

where yt-dlp >nul 2>nul
if errorlevel 1 (
	echo yt-dlp isn't installed: get it from https://github.com/yt-dlp/yt-dlp/releases
	pause
	exit /b 1
)
set "ffmpegArgs="
if exist "%~dp0..\..\Apps\FFmpeg\CLI\x64\bin\ffmpeg.exe" set "ffmpegArgs=--ffmpeg-location "%~dp0..\..\Apps\FFmpeg\CLI\x64\bin\ffmpeg.exe""

call :video big-buck-bunny aqz-KE-bpKQ
call :video crab-rave LDU_Txk06tM
call :video lg-oled njX2bu-_Vw4
call :video lg-qned WEwgbKr5R9I

echo:
echo End of script
rem pause
exit /b

rem :video <name> <YouTube video id>
:video
echo:
echo Downloading %~1 videos...
for %%H in (144 240 360 480 720 1080 1440 2160) do (
	yt-dlp %ffmpegArgs% -f "bestvideo[height=%%H]+bestaudio" -o "%~1_%%Hp.%%(ext)s" --merge-output-format mp4 --remux-video mp4 "https://www.youtube.com/watch?v=%~2"
)
exit /b
