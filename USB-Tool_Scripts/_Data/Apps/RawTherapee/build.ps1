param([string]$Version, [string]$WorkDir, [switch]$KeepWork, [switch]$Yes)
. "$PSScriptRoot\..\_Build-App.ps1"
trap { Stop-Build $_ }

# Builds RawTherapee from source (github.com/RawTherapee/RawTherapee) into Built\x64, the way its Windows CI
# (.github/workflows/windows.yml) does: MSYS2's UCRT64 environment (GCC, GTKmm 3, lcms2, FFTW, Lensfun, libjxl,
# exiv2, ...), CMake + Ninja (release, PROC_TARGET_NUMBER=1 for any x64 CPU), "cmake --build build --target install",
# then the same bundling: the DLLs rawtherapee.exe needs, gdbus / gspawn helpers, the Adwaita icons, gdk-pixbuf
# loaders, GLib schemas, a GTK settings.ini and the Lensfun database - like the official win64 zip.
# Differences: the DLL list is read from the import tables with objdump (the CI's ldd would start rawtherapee.exe).
# ARM64 isn't built (the CI builds it in MSYS2's CLANGARM64 on an ARM64 machine).
# Needs: a portable MSYS2 (UCRT64 GCC, GTKmm 3 and the other libraries), downloaded into the tools folder when missing
# Usage: build.cmd [-Version <x.y>] [-KeepWork] [-WorkDir <folder>]

$repo = 'RawTherapee/RawTherapee'
$tag = if ($Version) { $Version } else { Get-LatestGitHubTag $repo }
$work = Start-Build -Name 'RawTherapee' -NeedGB 6
$src = Join-Path $work 'src'
Get-GitSource "https://github.com/$repo.git" $tag $src

# (the CI's pacboy list, for UCRT64)
$pkgs = 'gcc', 'pkgconf', 'cmake', 'autotools', 'ninja', 'gtkmm3', 'lcms2', 'fftw', 'lensfun', 'libiptcdata', 'libjxl', 'exiv2'
Use-Msys2 -Packages (@('git', 'intltool') + ($pkgs | ForEach-Object { "mingw-w64-ucrt-x86_64-$_" }))

# the build, as a shell script run in MSYS2's ucrt64 environment: build-rawtherapee.sh
$script = @'
set -e
cd src
cmake -G Ninja -DCMAKE_BUILD_TYPE=release -DCACHE_NAME_SUFFIX="" -DPROC_TARGET_NUMBER=1 \
    -DLENSFUNDBDIR=share/lensfun -DWITH_SIMDE=OFF -S . -B build
cmake --build build --target install --parallel 4
out="$(pwd)/build/release"
[ -f "$out/rawtherapee.exe" ] || { echo "The build didn't make $out/rawtherapee.exe"; exit 1; }
# Lensfun's database (lensfun-update-data downloads the newest; the package's own copy otherwise)
PYTHONPATH=/ucrt64/lib/site-packages lensfun-update-data || true
mkdir -p "$out/share"
if [ -d /ucrt64/var/lib/lensfun-updates/version_1 ]; then cp -R /ucrt64/var/lib/lensfun-updates/version_1 "$out/share/lensfun"
else cp -R /ucrt64/share/lensfun/version_1 "$out/share/lensfun"; fi
# the UCRT64 DLLs the programs load, read from their import tables (objdump), following each DLL's own imports
cp /ucrt64/bin/gdbus.exe /ucrt64/bin/gspawn-win64-helper.exe /ucrt64/bin/gspawn-win64-helper-console.exe "$out/"
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
add_dlls "$out"/*.exe
# Adwaita icons, gdk-pixbuf loaders (and their DLLs), GLib schemas and GTK settings, as the CI copies them
mkdir -p "$out/share/icons/Adwaita/symbolic"
for d in actions devices mimetypes places status ui; do
    if [ -d "/ucrt64/share/icons/Adwaita/symbolic/$d" ]; then cp -r "/ucrt64/share/icons/Adwaita/symbolic/$d" "$out/share/icons/Adwaita/symbolic/"; fi
done
cp /ucrt64/share/icons/Adwaita/index.theme "$out/share/icons/Adwaita/"
mkdir -p "$out/lib"
cp -r /ucrt64/lib/gdk-pixbuf-2.0 "$out/lib/gdk-pixbuf-2.0"
add_dlls "$out"/lib/gdk-pixbuf-2.0/2.10.0/loaders/*.dll
mkdir -p "$out/share/glib-2.0/schemas"
cp /ucrt64/share/glib-2.0/schemas/gschemas.compiled "$out/share/glib-2.0/schemas/"
mkdir -p "$out/share/gtk-3.0"
printf '[Settings]\ngtk-button-images=1\n' > "$out/share/gtk-3.0/settings.ini"
'@
[IO.File]::WriteAllText((Join-Path $work 'build-rawtherapee.sh'), ($script -replace "`r`n", "`n"))

Say "Building RawTherapee $tag for x64..."
Invoke-Msys2 -Env ucrt64 -Command 'bash ./build-rawtherapee.sh' -Dir $work
Publish-Build -From (Join-Path $src 'build\release') -Arch 'x64' -Version $tag -Note "Source: https://github.com/$repo, tag $tag (MSYS2 UCRT64, PROC_TARGET_NUMBER=1)"
Complete-Build
