param([string]$Version, [string]$WorkDir, [switch]$KeepWork, [switch]$Yes)
. "$PSScriptRoot\..\_Build-App.ps1"
trap { Stop-Build $_ }

# Builds TestDisk and PhotoRec from source (the release archive from cgsecurity.org, github.com/cgsecurity/testdisk)
# into Built\x64, the way the project's mingw-testdisk-copr.spec / compile.sh build it for MinGW (configure
# --enable-missing-uuid-ok --enable-qt --enable-record-compilation-date), with MSYS2's MinGW GCC, ncurses, libjpeg,
# zlib and Qt 5, laid out like the official win64 zip: testdisk_win.exe, photorec_win.exe, qphotorec_win.exe,
# fidentify_win.exe, the DLLs they need, platforms\qwindows.dll, qt.conf and the text files.
# Differences: the official zip's console programs are Cygwin builds (cygwin1.dll), these are MinGW ones like
# qphotorec; no libntfs (NTFS file listing / undelete) and no libewf (E01 images), which compile.sh builds from old
# sources that don't build here; only x64 (MSYS2 has no 32-bit Qt any more). Qt 6's lrelease makes the .qm files.
# PhotoRec's build.cmd runs this script too (its Built folder gets the same files, as update.cmd gives both the same zip).
# Needs: a portable MSYS2 (gcc, Qt 5, ncurses, libjpeg-turbo), downloaded into the tools folder when missing
# Usage: build.cmd [-Version <x.y>] [-KeepWork] [-WorkDir <folder>]

# (PhotoRec's build.ps1 sets these, so the build goes into its own Built folder)
$appTitle = if ($env:TESTDISK_BUILD_NAME) { $env:TESTDISK_BUILD_NAME } else { 'TestDisk' }
if (-not $Version) {
    # (the newest version on the download page update.cmd uses)
    $page = Get-Text 'https://www.cgsecurity.org/wiki/TestDisk_Download'
    $Version = [regex]::Matches($page, 'testdisk-([\d.]+)\.win64\.zip') | ForEach-Object { $_.Groups[1].Value } |
        Sort-Object { [version]($_ + $(if ($_ -notmatch '\.') { '.0' })) } | Select-Object -Last 1
    if (-not $Version) { throw "Couldn't find the latest version on cgsecurity.org" }
}
$work = Start-Build -Name $appTitle -NeedGB 3
if ($env:TESTDISK_BUILT_DIR) { $script:appDir = $env:TESTDISK_BUILT_DIR }

$pkgs = 'gcc', 'pkgconf', 'qt5-base', 'qt6-tools', 'ncurses', 'libjpeg-turbo', 'zlib', 'libiconv', 'gettext-runtime'
Use-Msys2 -Packages (@('make', 'tar', 'bzip2') + ($pkgs | ForEach-Object { "mingw-w64-x86_64-$_" }))
Get-File "https://www.cgsecurity.org/testdisk-$Version.tar.bz2" (Join-Path $work "testdisk-$Version.tar.bz2")

# the build, as a shell script run in MSYS2's mingw64 environment: build-testdisk.sh <version>
$script = @'
set -e
ver="$1"
tar xjf "testdisk-$ver.tar.bz2"
cd "testdisk-$ver"
# (MSYS2 has no Qt 5 lrelease any more; Qt 6's makes the same .qm files)
lrel="$(command -v lrelease-qt6 || command -v lrelease || true)"
[ -n "$lrel" ] || lrel=/mingw64/share/qt6/bin/lrelease.exe
./configure --host=x86_64-w64-mingw32 --build=x86_64-w64-mingw32 --prefix=/usr \
    --enable-missing-uuid-ok --enable-qt --enable-record-compilation-date LRELEASE="$lrel"
make -j4
out=../out
mkdir -p "$out/platforms"
for p in testdisk photorec fidentify qphotorec; do
    [ -f "src/$p.exe" ] || { echo "The build didn't make src/$p.exe"; exit 1; }
    strip -o "$out/${p}_win.exe" "src/$p.exe"
done
cp /mingw64/share/qt5/plugins/platforms/qwindows.dll "$out/platforms/"
# (the MinGW DLLs the programs and the Qt plugin load, read from their import tables with objdump, since ldd
# would have to start the programs, and they ask for admin rights)
todo="$(ls "$out"/*.exe "$out"/platforms/*.dll)"
while [ -n "$todo" ]; do
    next=""
    for f in $todo; do
        for d in $(objdump -p "$f" | awk '/DLL Name:/ {print $3}'); do
            if [ -f "/mingw64/bin/$d" ] && [ ! -f "$out/$d" ]; then cp "/mingw64/bin/$d" "$out/"; next="$next $out/$d"; fi
        done
    done
    todo="$next"
done
cp win/qt.conf win/readme.txt documentation.html INFO "$out/"
for f in AUTHORS COPYING NEWS THANKS; do cp "$f" "$out/$f.txt"; done
echo "$ver" > "$out/VERSION.txt"
'@
[IO.File]::WriteAllText((Join-Path $work 'build-testdisk.sh'), ($script -replace "`r`n", "`n"))

Say "Building TestDisk and PhotoRec $Version for x64..."
Invoke-Msys2 -Env mingw64 -Command "bash ./build-testdisk.sh $Version" -Dir $work
Publish-Build -From (Join-Path $work 'out') -Arch 'x64' -Version $Version -Note "Source: https://www.cgsecurity.org/testdisk-$Version.tar.bz2 (MSYS2 mingw64, Qt 5)"
Complete-Build
