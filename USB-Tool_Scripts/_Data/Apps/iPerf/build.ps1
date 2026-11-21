param([string]$Version, [string]$WorkDir, [switch]$KeepWork, [switch]$Yes)
. "$PSScriptRoot\..\_Build-App.ps1"
trap { Stop-Build $_ }

# Builds iperf3 from source (ESnet's release archive from downloads.es.net, github.com/esnet/iperf) into Built\x64,
# like the Windows builds update.cmd downloads (github.com/ar51an/iperf3-win-builds: the unmodified source built
# with a POSIX layer for Windows, statically linked, without OpenSSL): iperf3.exe and the runtime DLL beside it.
# Those builds use Cygwin (cygwin1.dll); this one uses MSYS2's msys environment, a fork of Cygwin, so the DLL beside
# iperf3.exe is msys-2.0.dll. (Cygwin itself only comes with an installer.)
# Needs: a portable MSYS2 (gcc, make), downloaded into the tools folder when missing
# Usage: build.cmd [-Version <x.y>] [-KeepWork] [-WorkDir <folder>]

# (the same version update.cmd downloads: the newest iperf3-win-builds release, named after the iperf version)
$ver = if ($Version) { $Version -replace '^v' } else { Get-LatestGitHubTag 'ar51an/iperf3-win-builds' }
$work = Start-Build -Name 'iPerf' -NeedGB 2

Use-Msys2 -Packages 'gcc', 'make', 'tar', 'gzip'
Get-File "https://downloads.es.net/pub/iperf/iperf-$ver.tar.gz" (Join-Path $work "iperf-$ver.tar.gz")

Say "Building iperf $ver (configure --disable-shared --without-openssl, make)..."
$cmd = @(
    "tar xzf iperf-$ver.tar.gz"
    "cd iperf-$ver"
    # (an older config.guess doesn't know MSYS2, which is Cygwin underneath)
    './configure --build=x86_64-pc-cygwin --disable-shared --enable-static --without-openssl --prefix=/usr'
    'make -j4'
    'mkdir -p ../out'
    'strip -o ../out/iperf3.exe src/iperf3.exe'
    'cp /usr/bin/msys-2.0.dll ../out/'
) -join ' && '
Invoke-Msys2 -Env msys -Command $cmd -Dir $work

Publish-Build -From (Join-Path $work 'out') -Arch 'x64' -Version $ver -Note "Source: https://downloads.es.net/pub/iperf/iperf-$ver.tar.gz (MSYS2 msys gcc, static, no OpenSSL)"
Complete-Build
