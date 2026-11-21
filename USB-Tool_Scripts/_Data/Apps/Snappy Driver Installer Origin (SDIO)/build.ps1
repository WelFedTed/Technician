param([string]$Version, [string]$WorkDir, [switch]$KeepWork, [switch]$Yes)
. "$PSScriptRoot\..\_Build-App.ps1"
trap { Stop-Build $_ }

# Builds Snappy Driver Installer Origin from source (its Subversion trunk on SourceForge) into Built\x86_x64, the way
# its Code::Blocks projects build the release exes, with MinGW GCC from MSYS2: project\Drivers.cbp's "Win32 Release"
# (SDIO_R<rev>.exe) and "Win64 Release" (SDIO_x64_R<rev>.exe), each linking the 7-Zip library from
# project\7zip\lib.cbp, and resources\install64.exe from project\install64\install64.cbp, all statically linked like
# the official exes. Code::Blocks can't run without its window, so this reads the .cbp files and turns each target's
# options, folders, libraries and source files into a makefile. The libraries are built from source first, at the
# versions the official exes use: Boost 1.81 (system, filesystem; the version the projects are set up for) and
# libtorrent-rasterbar 1.2.20 (static, deprecated functions on, no encryption), and libwebp (static).
# source\svnrev.h is made from source\svnrev_template.h with "svn info" (instead of TortoiseSVN's SubWCRev).
# Beside the exes go the trunk's SDIO_auto.bat, autorun.inf, del_old_driverpacks.bat, docs\, scripts\ and tools\, as
# in the official zip. Not built: the XP exes and the Translation Tool.
# Needs: a portable MSYS2 (gcc for mingw32 and mingw64, subversion, cmake, ninja) and 7-Zip, set up by the build
# (the work folder's path must be short: Boost's build tool can't use paths over 260 characters)
# Usage: build.cmd [-Version <svn revision, eg. 891>] [-KeepWork] [-WorkDir <folder>]   (default: the newest revision)

$svnUrl = 'https://svn.code.sf.net/p/snappy-driver-installer-origin/code/trunk'
$boostVersion = '1.81.0'
$libtorrentVersion = '1.2.20'
# (libwebp is built too: MSYS2 has no 32-bit one any more)
$webpVersion = '1.5.0'
$rev = if ($Version) { $Version -replace '^[rR]' } else { 'HEAD' }
# (named SDIO: a work folder without spaces or brackets, and short, since b2 and gcc can't use paths over 260 characters)
$work = Start-Build -Name 'SDIO' -NeedGB 8

Use-Msys2 -Packages 'subversion', 'make', 'tar', 'gzip', 'mingw-w64-x86_64-gcc', 'mingw-w64-i686-gcc', 'mingw-w64-x86_64-cmake', 'mingw-w64-x86_64-ninja'

Say "Getting the source (svn revision $rev)..."
Invoke-Msys2 -Env msys -Command "svn checkout -q --non-interactive -r $rev $svnUrl sdio && svn info --show-item last-changed-revision sdio > svn-rev.txt && svn info --show-item last-changed-date sdio > svn-date.txt" -Dir $work
$wcRev = ([IO.File]::ReadAllText((Join-Path $work 'svn-rev.txt'))).Trim()
$wcDate = [DateTime]::Parse(([IO.File]::ReadAllText((Join-Path $work 'svn-date.txt'))).Trim()).ToUniversalTime()
$sdio = Join-Path $work 'sdio'
Say "Revision $wcRev ($($wcDate.ToString('yyyy-MM-dd')))"

# source\svnrev.h, the way SubWCRev makes it from the template
$now = Get-Date
$inv = [Globalization.CultureInfo]::InvariantCulture
$t = [IO.File]::ReadAllText((Join-Path $sdio 'source\svnrev_template.h'))
$t = [regex]::Replace($t, '\$WCDATE=([^$]*)\$', { param($m) $wcDate.ToString(($m.Groups[1].Value -replace '%d', 'dd' -replace '%m', 'MM' -replace '%Y', 'yyyy' -replace '%b', 'MMM'), $inv) })
$t = [regex]::Replace($t, '\$WCNOW=([^$]*)\$', { param($m) $now.ToString(($m.Groups[1].Value -replace '%d', 'dd' -replace '%m', 'MM' -replace '%Y', 'yyyy' -replace '%b', 'MMM'), $inv) })
$t = $t.Replace('$WCREV$', $wcRev).Replace('$WCMODS?1:0$', '0')
[IO.File]::WriteAllText((Join-Path $sdio 'source\svnrev.h'), $t)

# Boost (source from boost.io) and libtorrent (release archive from GitHub)
$boostName = 'boost_' + $boostVersion.Replace('.', '_')
Say "Getting Boost $boostVersion..."
Get-File "https://archives.boost.io/release/$boostVersion/source/$boostName.7z" (Join-Path $work "$boostName.7z")
Expand-Archive7 (Join-Path $work "$boostName.7z") $work
Remove-Item -LiteralPath (Join-Path $work "$boostName.7z")
Say "Getting libtorrent $libtorrentVersion..."
Get-File "https://github.com/arvidn/libtorrent/releases/download/v$libtorrentVersion/libtorrent-rasterbar-$libtorrentVersion.tar.gz" (Join-Path $work "libtorrent-rasterbar-$libtorrentVersion.tar.gz")

Say "Getting libwebp $webpVersion..."
Get-File "https://storage.googleapis.com/downloads.webmproject.org/releases/webp/libwebp-$webpVersion.tar.gz" (Join-Path $work "libwebp-$webpVersion.tar.gz")

# the library builds, as a shell script run in MSYS2 for each architecture: build-libs.sh <x86|x64> <32|64> <boost folder> <libtorrent version> <libwebp version>
$libScript = @'
set -e
arch="$1"; bits="$2"; boost="$3"; lt="$4"; webp="$5"
work="$(pwd)"
# Boost: system and filesystem, static, with a static runtime (b2 is built again when the one there can't run in this
# environment: one built by the 32-bit gcc needs its DLLs)
if ! (cd "$boost" && ./b2 -v >/dev/null 2>&1); then (cd "$boost" && ./bootstrap.sh --with-toolset=gcc); fi
(cd "$boost" && ./b2 -j4 -q --hash toolset=gcc address-model=$bits link=static runtime-link=static threading=multi variant=release \
    --with-system --with-filesystem --layout=system --build-dir="../boost-build-$arch" --prefix="../boost-$arch" install)
# libtorrent: static, deprecated functions on (SDIO uses TORRENT_ABI_VERSION=1), without encryption, OpenSSL or iconv,
# which the official exes don't link (an MSYS2 OpenSSL would otherwise be picked up)
rm -rf "lt-$arch-src" "lt-build-$arch" && mkdir "lt-$arch-src"
tar xzf "libtorrent-rasterbar-$lt.tar.gz" -C "lt-$arch-src" --strip-components=1
/mingw64/bin/cmake -S "lt-$arch-src" -B "lt-build-$arch" -G Ninja -DCMAKE_MAKE_PROGRAM=/mingw64/bin/ninja.exe \
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_COMPILER=gcc -DCMAKE_CXX_COMPILER=g++ -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
    -DBUILD_SHARED_LIBS=OFF -Ddeprecated-functions=ON -Dencryption=OFF -Diconv=OFF -Dstatic_runtime=ON \
    -DCMAKE_DISABLE_FIND_PACKAGE_OpenSSL=ON -DCMAKE_DISABLE_FIND_PACKAGE_LibGcrypt=ON \
    -DBOOST_ROOT="$(cygpath -m "$work/boost-$arch")" -DBoost_ROOT="$(cygpath -m "$work/boost-$arch")" -DBoost_USE_STATIC_LIBS=ON -DBoost_USE_STATIC_RUNTIME=ON \
    -DCMAKE_INSTALL_PREFIX="$(cygpath -m "$work/libtorrent-$arch")"
/mingw64/bin/cmake --build "lt-build-$arch" --parallel 4
/mingw64/bin/cmake --install "lt-build-$arch"
# libwebp: static, the library only
rm -rf "webp-$arch-src" "webp-build-$arch" && mkdir "webp-$arch-src"
tar xzf "libwebp-$webp.tar.gz" -C "webp-$arch-src" --strip-components=1
/mingw64/bin/cmake -S "webp-$arch-src" -B "webp-build-$arch" -G Ninja -DCMAKE_MAKE_PROGRAM=/mingw64/bin/ninja.exe \
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_COMPILER=gcc -DBUILD_SHARED_LIBS=OFF -DWEBP_BUILD_ANIM_UTILS=OFF -DWEBP_BUILD_CWEBP=OFF \
    -DWEBP_BUILD_DWEBP=OFF -DWEBP_BUILD_GIF2WEBP=OFF -DWEBP_BUILD_IMG2WEBP=OFF -DWEBP_BUILD_VWEBP=OFF -DWEBP_BUILD_WEBPINFO=OFF \
    -DWEBP_BUILD_WEBPMUX=OFF -DWEBP_BUILD_EXTRAS=OFF -DCMAKE_INSTALL_PREFIX="$(cygpath -m "$work/webp-$arch")"
/mingw64/bin/cmake --build "webp-build-$arch" --parallel 4
/mingw64/bin/cmake --install "webp-build-$arch"
'@
[IO.File]::WriteAllText((Join-Path $work 'build-libs.sh'), ($libScript -replace "`r`n", "`n"))

# a Code::Blocks target as a makefile: the project's options then the target's (Code::Blocks' default order), its
# source files (.c with gcc, .cpp with g++, .rc with windres), and the library or exe it makes; paths stay relative to
# the .cbp's folder, as Code::Blocks runs the compiler there
function New-CbpMakefile([string]$Cbp, [string]$Target, [string[]]$ExtraCxxFlags, [string[]]$ExtraLibs) {
    [xml]$xml = [IO.File]::ReadAllText($Cbp)
    $project = $xml.CodeBlocks_project_file.Project
    $tgt = $project.Build.Target | Where-Object { $_.title -eq $Target }
    if (-not $tgt) { throw "$(Split-Path -Leaf $Cbp) has no target '$Target'" }
    $opt = { param($node, $name) ($node.Option | Where-Object { $_.$name } | Select-Object -First 1).$name }
    $adds = { param($section, $attr) @($project.$section.Add | Where-Object { $_.$attr } | ForEach-Object { $_.$attr }) + @($tgt.$section.Add | Where-Object { $_.$attr } | ForEach-Object { $_.$attr }) }
    # (the developer's own C:\ library folders become the ones built here)
    $mapDir = { param($d)
        if ($d -match '^C:/mingw') { return $null }
        $d = $d -replace '^C:/LIBTORRENT(32|64)(/DEBUG)?', '$$(LIBTORRENT)' -replace '^C:/BOOST(32|64)_\d+(/DEBUG)?', '$$(BOOST)'
        return $d
    }
    $cflags = & $adds 'Compiler' 'option'
    $incs = @(& $adds 'Compiler' 'directory' | ForEach-Object { & $mapDir $_ } | Where-Object { $_ } | ForEach-Object { "-I$_" })
    $ldflags = & $adds 'Linker' 'option'
    $libDirs = @(& $adds 'Linker' 'directory' | ForEach-Object { & $mapDir $_ } | Where-Object { $_ } | ForEach-Object { "-L$_" })
    $libs = @(& $adds 'Linker' 'library' | ForEach-Object { "-l$_" }) + $ExtraLibs
    $objDir = & $opt $tgt 'object_output'
    $output = & $opt $tgt 'output'
    $type = & $opt $tgt 'type'
    # (type 0 is a GUI program, which Code::Blocks links with -mwindows; 1 is a console program, 2 a static library)
    if ($type -eq '0') { $ldflags += '-mwindows' }
    $defines = @($cflags | Where-Object { $_ -like '-D*' })
    $objs = @(); $rules = @()
    foreach ($unit in $project.Unit) {
        $file = $unit.filename
        if ($file -notmatch '\.(c|cpp|rc)$') { continue }
        $targets = @($unit.Option | Where-Object { $_.target } | ForEach-Object { $_.target })
        if ($targets.Count -and $targets -notcontains $Target) { continue }
        if ($unit.Option | Where-Object { $_.compile -eq '0' }) { continue }
        if ($type -eq '2' -and $file -match '\.rc$') { continue }
        $obj = "$objDir/" + (($file -replace '^(\.\./)+', '') -replace '\.(c|cpp|rc)$', $(if ($file -match '\.rc$') { '.res.o' } else { '.o' }))
        $objs += $obj
        $cmd = switch -Regex ($file) {
            '\.cpp$' { "`$(CXX) `$(CXXFLAGS) `$(INCS) -c $file -o $obj" }
            '\.c$' { "`$(CC) `$(CXXFLAGS) `$(INCS) -c $file -o $obj" }
            '\.rc$' { "`$(WINDRES) `$(DEFINES) `$(INCS) -J rc -O coff -i $file -o $obj" }
        }
        $rules += "${obj}: $file`n`t@mkdir -p `$(@D)`n`t$cmd`n"
    }
    $dir = Split-Path -Parent $output; $name = Split-Path -Leaf $output
    if ($type -eq '2') { $result = "$dir/lib$name.a"; $link = "`t@mkdir -p `$(@D)`n`trm -f `$@`n`t`$(AR) rcs `$@ `$(OBJS)" }
    else { $result = "$output.exe"; $link = "`t`$(CXX) -o `$@ `$(OBJS) `$(LDFLAGS) `$(LIBDIRS) `$(LIBS)" }
    $mk = @(
        'CC ?= gcc', 'CXX ?= g++', 'WINDRES ?= windres', 'AR ?= ar'
        "CXXFLAGS = $(($cflags + $ExtraCxxFlags) -join ' ')"
        "DEFINES = $($defines -join ' ')"
        "INCS = $($incs -join ' ')"
        "LDFLAGS = $($ldflags -join ' ')"
        "LIBDIRS = $($libDirs -join ' ')"
        "LIBS = $($libs -join ' ')"
        "OBJS = $($objs -join ' ')"
        ''
        "${result}: `$(OBJS)`n$link`n"
    ) + $rules
    $mkFile = Join-Path (Split-Path -Parent $Cbp) ("build-" + ($Target -replace '\W', '-') + '.mk')
    [IO.File]::WriteAllText($mkFile, (($mk -join "`n") + "`n"))
    return @{ Makefile = Split-Path -Leaf $mkFile; Result = $result }
}

# (the trunk's copy of the 7-Zip source, external\SevenZ\build, lacks a few files the developer has, eg.
# CPP\Common\Common0.h: they're taken from the official source of the same 7-Zip version, only where missing)
$sevenZBuild = Join-Path $sdio 'external\SevenZ\build'
$verH = [IO.File]::ReadAllText((Join-Path $sevenZBuild 'C\7zVersion.h'))
$m = [regex]::Match($verH, '#define MY_VERSION_NUMBERS "(\d+)\.(\d+)"')
if (-not $m.Success) { throw "Couldn't read the 7-Zip version from external\SevenZ\build\C\7zVersion.h" }
$sevenZName = "7z$($m.Groups[1].Value)$($m.Groups[2].Value)-src.7z"
Say "Getting the missing 7-Zip source files ($sevenZName)..."
Get-File "https://www.7-zip.org/a/$sevenZName" (Join-Path $work $sevenZName)
$sevenZSrc = Join-Path $work '7zip-src'
Invoke-Checked (Get-SevenZip) x (Join-Path $work $sevenZName) "-o$sevenZSrc" -y | Out-Null
$added = 0
foreach ($file in Get-ChildItem -LiteralPath $sevenZSrc -Recurse -File | Where-Object { $_.FullName -match '\\(C|CPP)\\' }) {
    $rel = $file.FullName.Substring($sevenZSrc.Length + 1)
    $dest = Join-Path $sevenZBuild $rel
    if (-not (Test-Path -LiteralPath $dest) -and (Test-Path -LiteralPath (Split-Path -Parent $dest))) { Copy-Item -LiteralPath $file.FullName -Destination $dest; $added++ }
}
Say "(added $added files)"
# (resources.rc also names logoorigin128-blue.bmp, which isn't in the trunk either: the trunk's logoorigin128.bmp stands in)
$blue = Join-Path $sdio 'resources\logoorigin128-blue.bmp'
if (-not (Test-Path -LiteralPath $blue)) { Copy-Item -LiteralPath (Join-Path $sdio 'resources\logoorigin128.bmp') -Destination $blue; Say 'resources\logoorigin128-blue.bmp is missing from the trunk: using logoorigin128.bmp' }

$project = Join-Path $sdio 'project'
# resources\install64.exe (embedded by resources.rc): install64.cbp's Win64 Release, with the 64-bit gcc
Say 'Building install64.exe...'
$mk = New-CbpMakefile (Join-Path $project 'install64\install64.cbp') 'Win64 Release'
Invoke-Msys2 -Env mingw64 -Command "make -j4 -f $($mk.Makefile)" -Dir (Join-Path $project 'install64')
if (-not (Test-Path -LiteralPath (Join-Path $sdio 'resources\install64.exe'))) { throw "The build didn't make resources\install64.exe" }

$out = Join-Path $work 'out'
New-Item -ItemType Directory -Path $out -Force | Out-Null
foreach ($arch in @(@{ Name = 'x86'; Bits = '32'; Env = 'mingw32'; Target = 'Win32 Release'; Exe = "SDIO_R$wcRev.exe" }, @{ Name = 'x64'; Bits = '64'; Env = 'mingw64'; Target = 'Win64 Release'; Exe = "SDIO_x64_R$wcRev.exe" })) {
    Say "Building Boost and libtorrent for $($arch.Name)..."
    Invoke-Msys2 -Env $arch.Env -Command "bash ./build-libs.sh $($arch.Name) $($arch.Bits) $boostName $libtorrentVersion $webpVersion" -Dir $work

    # (the compile definitions and libraries libtorrent was built with, which code using it must match)
    $targets = Get-ChildItem -LiteralPath (Join-Path $work "libtorrent-$($arch.Name)") -Recurse -Filter 'LibtorrentRasterbarTargets.cmake' | Select-Object -First 1
    $ltDefs = @(); $ltLibs = @()
    if ($targets) {
        $cm = [IO.File]::ReadAllText($targets.FullName)
        $m = [regex]::Match($cm, 'INTERFACE_COMPILE_DEFINITIONS "([^"]*)"')
        if ($m.Success) { $ltDefs = @($m.Groups[1].Value -split ';' | Where-Object { $_ -and $_ -notmatch '\$<|^_?WIN32|WINNT|^UNICODE|^_UNICODE' } | ForEach-Object { "-D$_" }) }
        $m = [regex]::Match($cm, 'INTERFACE_LINK_LIBRARIES "([^"]*)"')
        if ($m.Success) { $ltLibs = @($m.Groups[1].Value -split ';' | Where-Object { $_ -match '^[A-Za-z0-9_]+$' } | ForEach-Object { "-l$_" }) }
    }
    # (libwebp's folders; newer libwebp needs its libsharpyuv after it)
    $webpDir = "../../webp-$($arch.Name)"
    $webpExtra = @("-L$webpDir/lib")
    if (Test-Path -LiteralPath (Join-Path $work "webp-$($arch.Name)\lib\libsharpyuv.a")) { $webpExtra += '-lsharpyuv' }

    Say "Building the 7-Zip library for $($arch.Name)..."
    $mk = New-CbpMakefile (Join-Path $project '7zip\lib.cbp') $arch.Target
    Invoke-Msys2 -Env $arch.Env -Command "make -j4 -f $($mk.Makefile)" -Dir (Join-Path $project '7zip')

    Say "Building SDIO for $($arch.Name)..."
    # (-include string / cstdint: the code relies on headers that GCC 8, which the official exes were built with, included
    # indirectly and newer GCCs don't; -fpermissive: with today's MinGW headers, strchr() on a const char* returns a const
    # char*, which the code assigns to char*)
    $mk = New-CbpMakefile (Join-Path $project 'Drivers.cbp') $arch.Target -ExtraCxxFlags ($ltDefs + @("-I$webpDir/include", '-include', 'string', '-include', 'cstdint', '-fpermissive')) -ExtraLibs ($ltLibs + $webpExtra + @('-lws2_32', '-lwsock32', '-liphlpapi', '-lmswsock'))
    Invoke-Msys2 -Env $arch.Env -Command "make -j4 -f $($mk.Makefile) BOOST=../../boost-$($arch.Name) LIBTORRENT=../../libtorrent-$($arch.Name)" -Dir $project
    $exe = Join-Path $project ($mk.Result -replace '/', '\')
    if (-not (Test-Path -LiteralPath $exe)) { throw "The build didn't make $($mk.Result)" }
    Copy-Item -LiteralPath $exe -Destination (Join-Path $out $arch.Exe)
}

# the trunk's other files, as in the official zip
foreach ($f in 'SDIO_auto.bat', 'autorun.inf', 'del_old_driverpacks.bat', 'docs', 'scripts', 'tools') {
    $p = Join-Path $sdio $f
    if (Test-Path -LiteralPath $p) { Copy-Item -LiteralPath $p -Destination $out -Recurse }
}
Publish-Build -From $out -Arch 'x86_x64' -Version "R$wcRev" -Note "Source: $svnUrl, revision $wcRev; Boost $boostVersion, libtorrent-rasterbar $libtorrentVersion, MSYS2 MinGW GCC"
Complete-Build
