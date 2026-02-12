@echo off

title Downloading Test Videos...


rem echo:
echo Downloading Big Buck Bunny Videos...
set "name=big-buck-bunny"
set "id=aqz-KE-bpKQ"
yt-dlp %id% -f 'bestvideo[height=144]+bestaudio -o %name%_144p --merge-output-format "mp4" --remux-video "mp4"
yt-dlp %id% -f 'bestvideo[height=240]+bestaudio -o %name%_240p --merge-output-format "mp4" --remux-video "mp4"
yt-dlp %id% -f 'bestvideo[height=360]+bestaudio -o %name%_360p --merge-output-format "mp4" --remux-video "mp4"
yt-dlp %id% -f 'bestvideo[height=480]+bestaudio -o %name%_480p --merge-output-format "mp4" --remux-video "mp4"
yt-dlp %id% -f 'bestvideo[height=720]+bestaudio -o %name%_720p --merge-output-format "mp4" --remux-video "mp4"
yt-dlp %id% -f 'bestvideo[height=1080]+bestaudio -o %name%_1080p --merge-output-format "mp4" --remux-video "mp4"
yt-dlp %id% -f 'bestvideo[height=1440]+bestaudio -o %name%_1440p --merge-output-format "mp4" --remux-video "mp4"
yt-dlp %id% -f 'bestvideo[height=2160]+bestaudio -o %name%_2160p --merge-output-format "mp4" --remux-video "mp4"

echo:
echo Downloading Crab Rave Videos...
set "name=crab-rave"
set "id=LDU_Txk06tM"
yt-dlp %id% -f 'bestvideo[height=144]+bestaudio -o %name%_144p --merge-output-format "mp4" --remux-video "mp4"
yt-dlp %id% -f 'bestvideo[height=240]+bestaudio -o %name%_240p --merge-output-format "mp4" --remux-video "mp4"
yt-dlp %id% -f 'bestvideo[height=360]+bestaudio -o %name%_360p --merge-output-format "mp4" --remux-video "mp4"
yt-dlp %id% -f 'bestvideo[height=480]+bestaudio -o %name%_480p --merge-output-format "mp4" --remux-video "mp4"
yt-dlp %id% -f 'bestvideo[height=720]+bestaudio -o %name%_720p --merge-output-format "mp4" --remux-video "mp4"
yt-dlp %id% -f 'bestvideo[height=1080]+bestaudio -o %name%_1080p --merge-output-format "mp4" --remux-video "mp4"
yt-dlp %id% -f 'bestvideo[height=1440]+bestaudio -o %name%_1440p --merge-output-format "mp4" --remux-video "mp4"
yt-dlp %id% -f 'bestvideo[height=2160]+bestaudio -o %name%_2160p --merge-output-format "mp4" --remux-video "mp4"

echo:
echo Downloading LG OLED Videos...
set "name=lg-oled"
set "id=njX2bu-_Vw4"
yt-dlp %id% -f 'bestvideo[height=144]+bestaudio -o %name%_144p --merge-output-format "mp4" --remux-video "mp4"
yt-dlp %id% -f 'bestvideo[height=240]+bestaudio -o %name%_240p --merge-output-format "mp4" --remux-video "mp4"
yt-dlp %id% -f 'bestvideo[height=360]+bestaudio -o %name%_360p --merge-output-format "mp4" --remux-video "mp4"
yt-dlp %id% -f 'bestvideo[height=480]+bestaudio -o %name%_480p --merge-output-format "mp4" --remux-video "mp4"
yt-dlp %id% -f 'bestvideo[height=720]+bestaudio -o %name%_720p --merge-output-format "mp4" --remux-video "mp4"
yt-dlp %id% -f 'bestvideo[height=1080]+bestaudio -o %name%_1080p --merge-output-format "mp4" --remux-video "mp4"
yt-dlp %id% -f 'bestvideo[height=1440]+bestaudio -o %name%_1440p --merge-output-format "mp4" --remux-video "mp4"
yt-dlp %id% -f 'bestvideo[height=2160]+bestaudio -o %name%_2160p --merge-output-format "mp4" --remux-video "mp4""

echo:
echo Downloading LG QNED Videos...
set "name=lg-qned"
set "id=WEwgbKr5R9I"
yt-dlp %id% -f 'bestvideo[height=144]+bestaudio -o %name%_144p --merge-output-format "mp4" --remux-video "mp4"
yt-dlp %id% -f 'bestvideo[height=240]+bestaudio -o %name%_240p --merge-output-format "mp4" --remux-video "mp4"
yt-dlp %id% -f 'bestvideo[height=360]+bestaudio -o %name%_360p --merge-output-format "mp4" --remux-video "mp4"
yt-dlp %id% -f 'bestvideo[height=480]+bestaudio -o %name%_480p --merge-output-format "mp4" --remux-video "mp4"
yt-dlp %id% -f 'bestvideo[height=720]+bestaudio -o %name%_720p --merge-output-format "mp4" --remux-video "mp4"
yt-dlp %id% -f 'bestvideo[height=1080]+bestaudio -o %name%_1080p --merge-output-format "mp4" --remux-video "mp4"
yt-dlp %id% -f 'bestvideo[height=1440]+bestaudio -o %name%_1440p --merge-output-format "mp4" --remux-video "mp4"
yt-dlp %id% -f 'bestvideo[height=2160]+bestaudio -o %name%_2160p --merge-output-format "mp4" --remux-video "mp4"


echo:
echo End of script
rem pause
exit /b