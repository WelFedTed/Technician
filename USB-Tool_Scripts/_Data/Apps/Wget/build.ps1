param([string]$Version, [string]$WorkDir, [switch]$KeepWork, [switch]$Yes)
. "$PSScriptRoot\..\_Build-App.ps1"
trap { Stop-Build $_ }

# Builds GNU Wget from source (the GNU release archive from ftp.gnu.org) into Built\x64 and Built\x86, like the
# eternallybored.org builds update.cmd downloads: a single statically linked wget.exe with OpenSSL, zlib, PCRE2,
# libpsl and c-ares, plus that site's two patches (taskbar progress bar, Windows certificate store) and the
# system-wide wgetrc in C:\Windows (as its 1.25.0 build has). It uses MSYS2's MinGW compilers and its static
# libraries instead of building each library from source like that site does; MSYS2 has no GPGME (used only for
# Metalink, so that's left out) and no 32-bit c-ares (the x86 wget uses Windows' own name lookup).
# Needs: a portable MSYS2 (gcc and the libraries for mingw64 and mingw32), downloaded into the tools folder when missing
# Usage: build.cmd [-Version <x.y.z>] [-KeepWork] [-WorkDir <folder>]

$site = 'https://eternallybored.org/misc/wget/'
if (-not $Version) {
    # (the newest version on the page update.cmd uses)
    $page = Get-Text $site
    $Version = [regex]::Matches($page, 'href=.([\d.]+)/64/wget\.exe') | ForEach-Object { $_.Groups[1].Value } |
        Sort-Object { [version]($_ + $(if ($_ -notmatch '\.') { '.0' })) } | Select-Object -Last 1
    if (-not $Version) { throw "Couldn't find the latest version on $site" }
}
$work = Start-Build -Name 'Wget' -NeedGB 2

$libs = 'gcc', 'pkgconf', 'openssl', 'zlib', 'pcre2', 'libpsl', 'libidn2', 'libunistring', 'libiconv'
Use-Msys2 -Packages (@('make', 'patch', 'tar', 'gzip', 'mingw-w64-x86_64-c-ares') + ($libs | ForEach-Object { "mingw-w64-x86_64-$_" }) + ($libs | ForEach-Object { "mingw-w64-i686-$_" }))

Get-File "https://ftp.gnu.org/gnu/wget/wget-$Version.tar.gz" (Join-Path $work "wget-$Version.tar.gz")
foreach ($p in 'taskbar-progress.patch', 'openssl-windows-cert-store.patch') { Get-File "${site}src/$p" (Join-Path $work $p) }

# the build steps, as a shell script (run in MSYS2 for each architecture: build-wget.sh <version> <host> <c-ares option> <folder>)
$script = @'
set -e
ver="$1"; host="$2"; cares="$3"; folder="$4"
rm -rf "build-$folder" && mkdir "build-$folder"
tar xzf "wget-$ver.tar.gz" -C "build-$folder" --strip-components=1
cd "build-$folder"
# (the taskbar patch also adds tbprogress.c to src/Makefile.am, written for an older wget; that one hunk is done
# in the generated src/Makefile.in instead, so automake doesn't have to run again)
patch -p1 --forward < ../taskbar-progress.patch || true
for f in src/tbprogress.c src/tbprogress.h; do test -f "$f" || { echo "taskbar-progress.patch didn't apply"; exit 1; }; done
if ls src/*.rej 2>/dev/null | grep -v 'src/Makefile.am.rej' >/dev/null; then echo "taskbar-progress.patch didn't apply"; exit 1; fi
sed -i -E 's/^(@OS_MSWINDOWS_TRUE@am__objects_[0-9]+ = mswindows\.\$\(OBJEXT\))$/\1 tbprogress.$(OBJEXT)/' src/Makefile.in
grep -q 'tbprogress.$(OBJEXT)' src/Makefile.in || { echo "Couldn't add tbprogress.c to src/Makefile.in"; exit 1; }
# (this patch names src/openssl.c without its folder)
patch -d src -p0 --forward < ../openssl-windows-cert-store.patch
./configure --host="$host" --build="$host" --prefix=/usr --sysconfdir=C:/Windows \
    --with-ssl=openssl $cares --with-libpsl --without-metalink --without-gpgme --disable-iri --disable-nls \
    --without-libuuid --enable-static --disable-shared --disable-dependency-tracking \
    PKG_CONFIG='pkg-config --static' LDFLAGS='-static -s' CFLAGS='-O2 -DPCRE2_STATIC -DOPENSSL_NO_SSL3_METHOD -Wno-error=incompatible-pointer-types -Wno-error=int-conversion -Wno-error=implicit-function-declaration' LIBS='-lcrypt32 -lws2_32 -liphlpapi -lole32' \
    gl_cv_var___daylight=__daylight gl_cv_sys_struct_timeval_tv_sec=yes
# (gl_cv_var___daylight: gnulib's test otherwise defines __daylight as daylight, which breaks MinGW's <time.h>,
# where __daylight is a function; gl_cv_sys_struct_timeval_tv_sec: gnulib would replace struct timeval with its own,
# which wget's c-ares code then hands to Winsock's select(); the -Wno-error flags: GCC 14 and newer make those old-C
# warnings errors; PCRE2_STATIC for the static PCRE2; OPENSSL_NO_SSL3_METHOD since OpenSSL 4 has no SSLv3 any more; ole32 for
# the taskbar patch's COM calls)
make -j4
mkdir -p "../out/$folder" && cp src/wget.exe "../out/$folder/"
'@
[IO.File]::WriteAllText((Join-Path $work 'build-wget.sh'), ($script -replace "`r`n", "`n"))

foreach ($arch in @(@{ Env = 'mingw64'; Host = 'x86_64-w64-mingw32'; Folder = 'x64'; Cares = '--with-cares' }, @{ Env = 'mingw32'; Host = 'i686-w64-mingw32'; Folder = 'x86'; Cares = '--without-cares' })) {
    Say "Building wget $Version for $($arch.Folder)..."
    # (no double quotes in the command: Windows PowerShell doesn't pass them on to bash)
    Invoke-Msys2 -Env $arch.Env -Command "bash ./build-wget.sh $Version $($arch.Host) $($arch.Cares) $($arch.Folder)" -Dir $work
    Publish-Build -From (Join-Path $work "out\$($arch.Folder)") -Arch $arch.Folder -Version $Version -Note "Source: https://ftp.gnu.org/gnu/wget/wget-$Version.tar.gz, with ${site}src/taskbar-progress.patch and openssl-windows-cert-store.patch (MSYS2 $($arch.Env), static)"
}
Complete-Build
