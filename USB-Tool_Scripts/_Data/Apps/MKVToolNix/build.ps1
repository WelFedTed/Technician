param([string]$Version, [string]$WorkDir, [switch]$KeepWork, [switch]$Yes)
. "$PSScriptRoot\..\_Build-App.ps1"
trap { Stop-Build $_ }

# Builds MKVToolNix from source (the release tarball from mkvtoolnix.download, codeberg.org/mbunkus/mkvtoolnix) into
# Built\x64, laid out like the portable 7z update.cmd downloads (packaging/windows/populate_installer_dir.sh):
# mkvmerge.exe, mkvinfo.exe, mkvextract.exe, mkvpropedit.exe, mkvtoolnix-gui.exe, tools\, data\ (with portable-app,
# so it keeps its settings beside itself), doc\, locale\ and examples\.
# The official Windows builds are cross-compiled on Linux with MXE; Building.for.Windows.md says it also builds on
# Windows itself with MinGW gcc (not officially supported), which is what MSYS2's own mingw-w64-mkvtoolnix package
# does. So this builds in MSYS2's UCRT64 environment the way that package's PKGBUILD does (configure + rake), with
# MSYS2's Qt 6, Boost, libebml, libmatroska and the other libraries.
# Differences: the libraries and Qt are DLLs beside the exes (Qt's by windeployqt, the rest found from the import
# tables) rather than linked statically, and doc\ has no HTML man pages (they need Saxon / Java).
# 32-bit isn't built (MSYS2 has no 32-bit Qt 6).
# Needs: a portable MSYS2 (UCRT64 GCC, Qt 6, Boost, Ruby and the other libraries and tools), downloaded into the
# tools folder when missing
# Usage: build.cmd [-Version <x.y>] [-KeepWork] [-WorkDir <folder>]

if (-not $Version) {
    $xml = Get-Text 'https://mkvtoolnix.download/latest-release.xml'
    $Version = [regex]::Match($xml, '<latest-source>.*?<version>([^<]+)</version>').Groups[1].Value
    if (-not $Version) { throw "Couldn't find the latest version in https://mkvtoolnix.download/latest-release.xml" }
}
$work = Start-Build -Name 'MKVToolNix' -NeedGB 6
Get-File "https://mkvtoolnix.download/sources/mkvtoolnix-$Version.tar.xz" (Join-Path $work "mkvtoolnix-$Version.tar.xz")

$libs = 'gcc', 'pkgconf', 'autotools', 'boost', 'fmt', 'gmp', 'libebml', 'libmatroska', 'pugixml', 'qt6-base',
    'qt6-multimedia', 'qt6-svg', 'qt6-tools', 'qt6-translations', 'cmark', 'docbook-xsl', 'libxslt', 'imagemagick',
    'inkscape', 'libogg', 'libvorbis', 'flac', 'libdvdread', 'ruby', 'shared-mime-info', 'xmlto', 'zlib'
Use-Msys2 -Packages (@('make', 'tar', 'xz', 'po4a', 'zsh') + ($libs | ForEach-Object { "mingw-w64-ucrt-x86_64-$_" }))

# the build, as a shell script run in MSYS2's ucrt64 environment: build-mkvtoolnix.sh <version>
$script = @'
set -e
ver="$1"
work="$(pwd)"
# (the tarball has symlinks whose targets come later in it, so it's extracted twice, like MSYS2's PKGBUILD does)
tar -xJf "mkvtoolnix-$ver.tar.xz" || true
tar -xJf "mkvtoolnix-$ver.tar.xz" || true
cd "mkvtoolnix-$ver"
[ -f configure ] || { echo "Couldn't extract mkvtoolnix-$ver.tar.xz"; exit 1; }
# (the PKGBUILD's prepare step: Qt's rcc finds freedesktop.org.xml beside the GUI's sources)
cp /ucrt64/share/mime/packages/freedesktop.org.xml src/mkvtoolnix-gui/freedesktop.org.xml
sed -i 's|/usr/share/mime/packages/freedesktop.org.xml|freedesktop.org.xml|g' src/mkvtoolnix-gui/qt_resources_windows.qrc
CXXFLAGS="-O2 -Wno-template-id-cdtor -Wno-ignored-attributes" ./configure --prefix=/ucrt64 \
    --with-boost-system=boost_filesystem-mt --with-boost-filesystem=boost_filesystem-mt \
    --disable-update-check ac_cv_lib_gtest_main_main=no
export DRAKETHREADS=4
rake -j 4
rake -j 4 apps:tools || true

# the portable layout (packaging/windows/populate_installer_dir.sh)
out="$work/out"
mkdir -p "$out/examples" "$out/data/sounds" "$out/doc/licenses" "$out/locale/libqt" "$out/tools"
cp src/*.exe src/mkvtoolnix-gui/*.exe "$out/"
cp packaging/windows/installer/*.url "$out/" 2>/dev/null || true
cp -R examples/* "$out/examples/"; rm -rf "$out/examples/stylesheets"
for t in bluray_dump ebml_validator hevcc_dump xyzvc_dump; do [ -f "src/tools/$t.exe" ] && cp "src/tools/$t.exe" "$out/tools/"; done
cp src/mkvtoolnix-gui/qt_resources.rcc "$out/data/" 2>/dev/null || true
cp share/sounds/*.webm "$out/data/sounds/" 2>/dev/null || true
touch "$out/data/portable-app"
cp README.md "$out/doc/README.txt"; cp COPYING "$out/doc/COPYING.txt"; cp NEWS.md "$out/doc/NEWS.txt"
cp doc/command_line_references.html "$out/doc/" 2>/dev/null || true
cp doc/licenses/*.txt "$out/doc/licenses/" 2>/dev/null || true
for mo in po/*.mo; do
    [ -f "$mo" ] || continue
    lang="$(basename "$mo" .mo)"
    mkdir -p "$out/locale/$lang/LC_MESSAGES" && cp "$mo" "$out/locale/$lang/LC_MESSAGES/mkvtoolnix.mo"
done
for qm in /ucrt64/share/qt6/translations/qt_*.qm; do
    case "$qm" in *qt_help*) continue ;; esac
    lang="${qm##*/qt_}"; lang="${lang%.qm}"
    base="/ucrt64/share/qt6/translations/qtbase_$lang.qm"; [ -f "$base" ] && qm="$base"
    cp "$qm" "$out/locale/libqt/qt_$lang.qm"
done
strip "$out"/*.exe "$out"/tools/*.exe
# Qt's DLLs and plugins (windeployqt), then every other UCRT64 DLL the exes and plugins load, from their import tables
deployqt="$(command -v windeployqt6 || command -v windeployqt-qt6 || echo /ucrt64/share/qt6/bin/windeployqt.exe)"
"$deployqt" --release --no-translations --no-compiler-runtime --dir "$out" "$out/mkvtoolnix-gui.exe"
add_dlls() {
    todo="$*"
    while [ -n "$todo" ]; do
        next=""
        for f in $todo; do
            for d in $(objdump -p "$f" | awk '/DLL Name:/ {print $3}'); do
                if [ -f "/ucrt64/bin/$d" ] && [ ! -f "$out/$d" ]; then cp "/ucrt64/bin/$d" "$out/"; next="$next $out/$d"; fi
            done
        done
        todo="$next"
    done
}
add_dlls "$out"/*.exe "$out"/tools/*.exe $(find "$out" -name '*.dll')
# (a check with only Windows on the PATH, so a DLL missing from out shows up here)
PATH=/c/Windows/System32:/c/Windows "$out/mkvmerge.exe" --version
'@
[IO.File]::WriteAllText((Join-Path $work 'build-mkvtoolnix.sh'), ($script -replace "`r`n", "`n"))

Say "Building MKVToolNix $Version for x64..."
Invoke-Msys2 -Env ucrt64 -Command "bash ./build-mkvtoolnix.sh '$Version'" -Dir $work
Publish-Build -From (Join-Path $work 'out') -Arch 'x64' -Version $Version -Note "Source: https://mkvtoolnix.download/sources/mkvtoolnix-$Version.tar.xz (MSYS2 UCRT64, Qt 6 and the libraries as DLLs)"
Complete-Build
