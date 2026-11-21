param([string]$Version, [string]$WorkDir, [switch]$KeepWork, [switch]$Yes)
. "$PSScriptRoot\..\_Build-App.ps1"
trap { Stop-Build $_ }

# Builds FFmpeg from source (the release tag from github.com/FFmpeg/FFmpeg, the mirror of git.ffmpeg.org) into
# Built\x64, like the gyan.dev "release essentials" build update.cmd downloads: bin\ffmpeg.exe, ffprobe.exe and
# ffplay.exe (GPLv3), with that build's list of libraries (x264, x265, libvpx, libaom, libwebp, libass, freetype,
# harfbuzz, fribidi, fontconfig, opus, vorbis, lame, theora, speex, gsm, opencore-amr, vo-amrwbenc, openjpeg,
# openmpt, gme, rubberband, vidstab, vmaf, xvid, zimg, zmq, srt, libssh, libcurl, cairo, openal, SDL2, AviSynth+,
# VapourSynth, libvpl, AMF, NVENC / NVDEC / CUVID, D3D11VA / D3D12VA / DXVA2, Media Foundation), plus doc\ (HTML)
# and presets\.
# gyan.dev builds natively on Windows in MSYS2 (media-autobuild_suite), so this does too, in MSYS2's UCRT64
# environment, with MSYS2's packages of those libraries instead of building each one from source.
# Differences: the libraries are linked as DLLs (copied into bin\ beside the exes, found from their import tables)
# rather than statically into each exe, and CUDA filters that need clang (cuda-llvm) aren't built.
# Needs: a portable MSYS2 (UCRT64 GCC, NASM and the libraries), downloaded into the tools folder when missing
# Usage: build.cmd [-Version <x.y[.z]>] [-KeepWork] [-WorkDir <folder>]

$repo = 'FFmpeg/FFmpeg'
if ($Version) { $tag = 'n' + ($Version -replace '^n') }
else {
    # (the newest release tag, nX.Y[.Z]: the GitHub mirror has tags but no releases)
    $git = Get-Git
    $tags = & $git ls-remote --tags --refs "https://github.com/$repo.git" 'n*' | ForEach-Object { ($_ -split 'refs/tags/')[1] } | Where-Object { $_ -match '^n\d+(\.\d+)+$' }
    if ($LASTEXITCODE -ne 0 -or -not $tags) { throw "Couldn't read the tags of https://github.com/$repo.git" }
    $tag = $tags | Sort-Object { [version](($_ -replace '^n') + $(if ($_ -notmatch '\.') { '.0' })) } | Select-Object -Last 1
}
$ver = $tag -replace '^n'
$work = Start-Build -Name 'FFmpeg' -NeedGB 4
$src = Join-Path $work 'src'
Get-GitSource "https://github.com/$repo.git" $tag $src
# (AviSynth+'s C headers: FFmpeg loads AviSynth.dll itself when a script is opened; MSYS2 has no package of them)
$avsRepo = 'AviSynth/AviSynthPlus'
$avsTag = Get-LatestGitHubTag $avsRepo
Get-GitSource "https://github.com/$avsRepo.git" $avsTag (Join-Path $work 'avisynthplus')

$libs = 'gcc', 'nasm', 'pkgconf', 'cmake', 'aom', 'libass', 'freetype', 'fribidi', 'harfbuzz', 'fontconfig', 'libgme',
    'gsm', 'lame', 'opencore-amr', 'openjpeg2', 'libopenmpt', 'opus', 'rubberband', 'speex', 'srt', 'libssh',
    'libtheora', 'vid.stab', 'vmaf', 'vo-amrwbenc', 'libvorbis', 'libvpx', 'libwebp', 'libx264', 'x265', 'xvidcore',
    'zimg', 'zeromq', 'openal', 'SDL2', 'vapoursynth', 'amf-headers', 'ffnvcodec-headers', 'libvpl', 'cairo', 'curl'
Use-Msys2 -Packages (@('make', 'diffutils', 'texinfo') + ($libs | ForEach-Object { "mingw-w64-ucrt-x86_64-$_" }))

# the build, as a shell script run in MSYS2's ucrt64 environment: build-ffmpeg.sh
$script = @'
set -e
work="$(pwd)"
# AviSynth+ headers only (its documented "HEADERS_ONLY" install)
cmake -G "MSYS Makefiles" -S avisynthplus -B avisynthplus/build -DHEADERS_ONLY=ON -DCMAKE_INSTALL_PREFIX="$work/deps"
make -C avisynthplus/build VersionGen install
cd src
./configure --arch=x86_64 --target-os=mingw32 --pkg-config=pkg-config --extra-cflags="-I$work/deps/include" \
    --disable-debug --disable-manpages --disable-podpages --disable-txtpages --enable-htmlpages \
    --enable-gpl --enable-version3 --enable-runtime-cpudetect \
    --enable-avisynth --enable-cairo --enable-libaom --enable-libass --enable-libcurl --enable-libfreetype \
    --enable-libfontconfig --enable-libfribidi --enable-libharfbuzz --enable-libgme --enable-libgsm \
    --enable-libmp3lame --enable-libopencore-amrnb --enable-libopencore-amrwb --enable-libopenjpeg \
    --enable-libopenmpt --enable-libopus --enable-librubberband --enable-libspeex --enable-libsrt --enable-libssh \
    --enable-libtheora --enable-libvidstab --enable-libvmaf --enable-libvo-amrwbenc --enable-libvorbis \
    --enable-libvpx --enable-libwebp --enable-libx264 --enable-libx265 --enable-libxvid --enable-libzimg \
    --enable-libzmq --enable-mediafoundation --enable-openal --enable-sdl2 --enable-vapoursynth \
    --enable-libvpl --enable-amf --enable-ffnvcodec --enable-cuvid --enable-nvdec --enable-nvenc \
    --enable-d3d11va --enable-d3d12va --enable-dxva2
make -j4
out="$work/out"
mkdir -p "$out/bin" "$out/doc" "$out/presets"
cp ffmpeg.exe ffprobe.exe ffplay.exe "$out/bin/"
strip "$out"/bin/*.exe
cp doc/*.html doc/*.css "$out/doc/" 2>/dev/null || true
cp presets/*.ffpreset "$out/presets/"
cp COPYING.GPLv3 "$out/LICENSE"
# the UCRT64 DLLs the exes load, read from their import tables (objdump), following each DLL's own imports
add_dlls() {
    todo="$*"
    while [ -n "$todo" ]; do
        next=""
        for f in $todo; do
            for d in $(objdump -p "$f" | awk '/DLL Name:/ {print $3}'); do
                if [ -f "/ucrt64/bin/$d" ] && [ ! -f "$out/bin/$d" ]; then cp "/ucrt64/bin/$d" "$out/bin/"; next="$next $out/bin/$d"; fi
            done
        done
        todo="$next"
    done
}
add_dlls "$out"/bin/*.exe
# (a check with only Windows on the PATH, so a DLL missing from bin shows up here)
PATH=/c/Windows/System32:/c/Windows "$out/bin/ffmpeg.exe" -hide_banner -version > "$work/ffmpeg-version.txt"
head -1 "$work/ffmpeg-version.txt"
'@
[IO.File]::WriteAllText((Join-Path $work 'build-ffmpeg.sh'), ($script -replace "`r`n", "`n"))

Say "Building FFmpeg $ver for x64..."
Invoke-Msys2 -Env ucrt64 -Command 'bash ./build-ffmpeg.sh' -Dir $work
Publish-Build -From (Join-Path $work 'out') -Arch 'x64' -Version $ver -Note "Source: https://github.com/$repo, tag $tag (MSYS2 UCRT64, the gyan.dev essentials libraries as DLLs; AviSynth+ headers $avsTag)"
Complete-Build
