param([string]$Version, [string]$WorkDir, [switch]$KeepWork, [switch]$Yes)
. "$PSScriptRoot\..\_Build-App.ps1"
trap { Stop-Build $_ }

# Builds qBittorrent from source (github.com/qbittorrent/qBittorrent) into Built\x64, the way its Windows CI
# (.github/workflows/ci_windows.yaml) does: OpenSSL, zlib and b2 from vcpkg (an x64-windows-static-md-release
# triplet), the Boost headers, libtorrent 2.0.x (the version and Boost the CI pairs) built with CMake + Ninja, Qt 6
# (the CI's version: qtbase, qtsvg, qttools, qtimageformats) from download.qt.io, then qBittorrent with CMake + Ninja
# and MSVC; laid out like the CI's artifact: qbittorrent.exe, qt.conf, the Qt DLLs and the plugins it lists.
# Differences: the official installer's qbittorrent.exe links Qt statically; this one has Qt's DLLs beside it.
# Release build (the CI builds RelWithDebInfo, with tests).
# Needs: Visual Studio 2022 with C++, CMake; vcpkg, Qt (aqtinstall, with a portable Python), Boost's source and
# Ninja, downloaded when missing
# Usage: build.cmd [-Version <x.y.z>] [-KeepWork] [-WorkDir <folder>]

$repo = 'qbittorrent/qBittorrent'
$tag = if ($Version) { 'release-' + ($Version -replace '^release-') } else { Get-LatestGitHubTag $repo }
$ver = $tag -replace '^release-'
$work = Start-Build -Name 'qBittorrent' -NeedGB 10
$src = Join-Path $work 'src'
Get-GitSource "https://github.com/$repo.git" $tag $src
if (-not (Get-Command cmake.exe -ErrorAction SilentlyContinue)) { throw 'This build needs CMake (cmake.org) on the PATH' }

# (the libtorrent 2.0 / Boost / Qt versions the CI uses)
$ci = [IO.File]::ReadAllText((Join-Path $src '.github\workflows\ci_windows.yaml'))
$m = [regex]::Match($ci, 'version: "(2\.0\.\d+)"\s+boost_major_version: "(\d+)"\s+boost_minor_version: "(\d+)"\s+boost_patch_version: "(\d+)"')
if (-not $m.Success) { throw "Couldn't find the libtorrent 2.0 version in ci_windows.yaml" }
$ltVer = $m.Groups[1].Value; $boostVer = "$($m.Groups[2].Value).$($m.Groups[3].Value).$($m.Groups[4].Value)"
$m = [regex]::Match($ci, 'install-qt-action@\S+\s+with:\s+version: "([\d.]+)"')
$qtVer = if ($m.Success) { $m.Groups[1].Value } else { '6.10.3' }

# Qt from download.qt.io with aqtinstall (in a venv), kept in the tools folder (Qt\<version>\<arch folder>), so the
# next build doesn't download it again; adds its bin folder to the PATH and returns the Qt folder
# (-Arch: aqt's name, eg. win64_msvc2022_64, win32_msvc2019, win32_mingw81; -Modules: aqt's add-on module names;
# -Archives: only these parts of the base Qt, eg. qtbase qtsvg qttools)
function Get-Aqt {
    $aqtVenv = Join-Path $script:toolsDir 'aqt-venv'
    $aqtPy = Join-Path $aqtVenv 'Scripts\python.exe'
    if (-not (Test-Path -LiteralPath $aqtPy)) {
        Use-Tool python -Version '3.9'
        Say 'Getting aqtinstall (the Qt downloader)...'
        Invoke-Checked python -m venv $aqtVenv | Out-Host
        Invoke-Checked $aqtPy -m pip install --disable-pip-version-check -q aqtinstall | Out-Host
    }
    return $aqtPy
}
function Invoke-Aqt([string[]]$AqtArgs) {
    # (a second try: a virus scanner sometimes still has a new qmake.exe open when aqt patches it)
    $aqtPy = Get-Aqt
    # (aqt writes its aqtinstall.log into the current folder, so it runs in the tools folder)
    Push-Location -LiteralPath $script:toolsDir
    try {
        for ($try = 1; $try -le 2; $try++) {
            # (its output goes to the console, not into Use-Qt's result)
            & $aqtPy -m aqt @AqtArgs | Out-Host
            if ($LASTEXITCODE -eq 0) { return }
            if ($try -lt 2) { Say 'aqt failed; trying again...'; Start-Sleep -Seconds 10 }
        }
    }
    finally { Pop-Location }
    throw "aqt $($AqtArgs -join ' ') failed (exit code $LASTEXITCODE)"
}
# Qt 6.11 and newer: download.qt.io splits each Qt version's repository by architecture, which aqtinstall 3.3 can't
# read yet, so these come straight from that repository: its Updates.xml names each package's archives and the
# folder they go into
function Install-QtDirect([string]$Version, [string]$Arch, [string[]]$Modules, [string[]]$Archives, [string]$QtRoot) {
    $v = $Version -replace '\.', ''
    $base = "https://download.qt.io/online/qtsdkrepository/windows_x86/desktop/qt6_$v/qt6_${v}_$($Arch -replace '^win64_', '')"
    [xml]$updates = Get-Text "$base/Updates.xml"
    $names = @("qt.qt6.$v.$Arch") + @($Modules | Where-Object { $_ } | ForEach-Object { "qt.qt6.$v.addons.$_.$Arch" })
    $target = $null
    foreach ($name in $names) {
        $pkg = $updates.Updates.PackageUpdate | Where-Object { $_.Name -eq $name } | Select-Object -First 1
        if (-not $pkg) { throw "Qt $Version has no package $name ($base/Updates.xml)" }
        foreach ($op in @($pkg.Operations.Operation | Where-Object { $_.name -eq 'Extract' })) {
            $into = $op.Argument[0] -replace '^@TargetDir@', $QtRoot
            $archive = $op.Argument[1]
            # (not the documentation; with -Archives, only those parts of the base Qt)
            if ($archive -match '^qtdoc-') { continue }
            if ($Archives -and $name -eq $names[0] -and -not ($Archives | Where-Object { $archive -like "$_-*" })) { continue }
            $file = Join-Path $QtRoot "_download\$archive"
            Get-File "$base/$name/$($pkg.Version)$archive" $file
            Expand-Archive7 $file $into
            Remove-Item -LiteralPath $file
            if ($name -eq $names[0]) { $target = $into }
        }
    }
    # (Qt's tools find their own folder from qt.conf, as the Qt installer / aqt set it up)
    if ($target -and (Test-Path -LiteralPath "$target\bin")) { [IO.File]::WriteAllText("$target\bin\qt.conf", "[Paths]`r`nPrefix=..`r`n") }
}
function Use-Qt([string]$Version, [string]$Arch = 'win64_msvc2022_64', [string[]]$Modules, [string[]]$Archives) {
    $qtRoot = Join-Path $script:toolsDir 'Qt'
    # (aqt's folder names: win64_msvc2022_64 > msvc2022_64, win32_msvc2019 > msvc2019, win32_mingw81 > mingw81_32)
    $folder = $Arch -replace '^win(32|64)_', ''
    $folder = $folder -replace '_cross_compiled$', ''
    if ($Arch -match '^win32_mingw') { $folder += '_32' } elseif ($Arch -match '^win64_mingw' -and $folder -notmatch '_64$') { $folder += '_64' }
    $dir = Join-Path $qtRoot "$Version\$folder"
    $stamp = Join-Path $dir ".aqt-$((@($Modules) + @($Archives) | Where-Object { $_ } | Sort-Object) -join '-').ok"
    if (-not (Test-Path -LiteralPath $stamp)) {
        Say "Getting Qt $Version ($Arch$(if ($Modules) { ', ' + ($Modules -join ', ') }))..."
        $aqtArgs = @('install-qt', 'windows', 'desktop', $Version, $Arch, '--outputdir', $qtRoot)
        if ($Modules) { $aqtArgs += @('--modules') + $Modules }
        if ($Archives) { $aqtArgs += @('--archives') + $Archives }
        if ([version]$Version -ge [version]'6.11') { Install-QtDirect -Version $Version -Arch $Arch -Modules $Modules -Archives $Archives -QtRoot $qtRoot }
        else { Invoke-Aqt $aqtArgs }
        if (-not (Test-Path -LiteralPath "$dir\bin")) { throw "Getting Qt didn't make $dir" }
        [IO.File]::WriteAllText($stamp, '')
    }
    Add-ToPath "$dir\bin"
    return $dir
}
# (end of Use-Qt)
# vcpkg, a shallow checkout of one commit (or the newest) in the tools folder, with its downloads and binary cache
# there too (not in %LOCALAPPDATA%); sets VCPKG_ROOT and returns its folder
function Use-Vcpkg([string]$Commit) {
    $dir = Join-Path $script:toolsDir 'vcpkg'
    $git = Get-Git
    if (-not (Test-Path -LiteralPath (Join-Path $dir '.git'))) {
        Say 'Getting vcpkg...'
        Invoke-Checked $git clone -q --depth 1 https://github.com/microsoft/vcpkg.git $dir | Out-Host
    }
    $want = if ($Commit) { $Commit } else { 'master' }
    $head = (& $git -C $dir rev-parse HEAD | Out-String).Trim()
    if (-not $Commit -or $head -ne $Commit) {
        Invoke-Checked $git -C $dir fetch -q --depth 1 origin $want | Out-Host
        Invoke-Checked $git -C $dir -c advice.detachedHead=false checkout -q --force FETCH_HEAD | Out-Host
    }
    $stamp = Join-Path $dir 'vcpkg.exe.commit'
    $head = (& $git -C $dir rev-parse HEAD | Out-String).Trim()
    if (-not (Test-Path -LiteralPath (Join-Path $dir 'vcpkg.exe')) -or -not (Test-Path -LiteralPath $stamp) -or [IO.File]::ReadAllText($stamp) -ne $head) {
        Invoke-Checked (Join-Path $dir 'bootstrap-vcpkg.bat') -disableMetrics | Out-Host
        [IO.File]::WriteAllText($stamp, $head)
    }
    $env:VCPKG_ROOT = $dir; $env:VCPKG_DISABLE_METRICS = '1'; $env:VCPKG_MAX_CONCURRENCY = '4'
    $env:VCPKG_DOWNLOADS = Join-Path $script:toolsDir 'vcpkg-downloads'
    $env:VCPKG_DEFAULT_BINARY_CACHE = Join-Path $script:toolsDir 'vcpkg-cache'
    New-Item -ItemType Directory -Path $env:VCPKG_DOWNLOADS, $env:VCPKG_DEFAULT_BINARY_CACHE -Force | Out-Null
    return $dir
}
$vcpkg = Use-Vcpkg
Use-Tool ninja
$qtDir = Use-Qt -Version $qtVer -Arch 'win64_msvc2022_64' -Archives 'qtbase', 'qtsvg', 'qttools' -Modules 'qtimageformats'
$env:PATH = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer;$env:PATH"
Use-VisualStudio -Arch x64 -Version '[17.0,18.0)' | Out-Null

Say "Getting OpenSSL, zlib and b2 (vcpkg)..."
$triplet = 'x64-windows-static-md-release'
$triplets = Join-Path $work 'triplets'
New-Item -ItemType Directory -Path $triplets -Force | Out-Null
[IO.File]::WriteAllText((Join-Path $triplets "$triplet.cmake"), "set(VCPKG_TARGET_ARCHITECTURE x64)`nset(VCPKG_LIBRARY_LINKAGE static)`nset(VCPKG_CRT_LINKAGE dynamic)`nset(VCPKG_BUILD_TYPE release)`n")
$installed = Join-Path $work 'vcpkg_installed'
Invoke-Checked (Join-Path $vcpkg 'vcpkg.exe') install --clean-after-build "--overlay-triplets=$triplets" "--x-install-root=$installed" "boost-build:$triplet" "openssl:$triplet" "zlib:$triplet"
$toolchain = @("-DCMAKE_TOOLCHAIN_FILE=$vcpkg\scripts\buildsystems\vcpkg.cmake", "-DVCPKG_TARGET_TRIPLET=$triplet", "-DVCPKG_INSTALLED_DIR=$installed", '-DVCPKG_MANIFEST_MODE=OFF', "-DVCPKG_OVERLAY_TRIPLETS=$triplets")

Say "Getting the Boost $boostVer headers..."
$boostTgz = Join-Path $work 'boost.tar.gz'
$boostFile = "boost_$($boostVer -replace '\.', '_')"
try { Get-File "https://archives.boost.io/release/$boostVer/source/$boostFile.tar.gz" $boostTgz }
catch { Get-File "https://sourceforge.net/projects/boost/files/boost/$boostVer/$boostFile.tar.gz/download" $boostTgz }
Invoke-Checked tar.exe -xf $boostTgz -C $work
$boost = Join-Path $work 'boost'
Rename-Item -LiteralPath (Join-Path $work $boostFile) -NewName 'boost'
Push-Location -LiteralPath $boost
try { Invoke-Checked (Join-Path $installed "$triplet\tools\boost-build\b2.exe") stage toolset=msvc '--stagedir=.\' --with-headers }
finally { Pop-Location }

Say "Building libtorrent $ltVer..."
$lt = Join-Path $work 'libtorrent'
Get-GitSource 'https://github.com/arvidn/libtorrent.git' "v$ltVer" $lt -Submodules
$env:CFLAGS = '/guard:cf'; $env:CXXFLAGS = '/guard:cf'; $env:LDFLAGS = '/GUARD:CF'
Invoke-Checked cmake -S $lt -B "$lt\build" -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_CXX_STANDARD=20 "-DCMAKE_INSTALL_PREFIX=$lt\install" @toolchain `
    "-DBOOST_ROOT=$boost\lib\cmake" -DBUILD_SHARED_LIBS=OFF -Ddeprecated-functions=OFF -Dstatic_runtime=OFF
Invoke-Checked cmake --build "$lt\build" --parallel 4
Invoke-Checked cmake --install "$lt\build"
Remove-Item Env:CFLAGS, Env:CXXFLAGS, Env:LDFLAGS

Say "Building qBittorrent $ver for x64 (libtorrent $ltVer, Qt $qtVer)..."
$build = Join-Path $work 'build'
Invoke-Checked cmake -S $src -B $build -G Ninja -DCMAKE_BUILD_TYPE=Release @toolchain "-DCMAKE_PREFIX_PATH=$qtDir" `
    "-DBOOST_ROOT=$boost\lib\cmake" "-DLibtorrentRasterbar_DIR=$lt\install\lib\cmake\LibtorrentRasterbar" -DMSVC_RUNTIME_DYNAMIC=ON -DTESTING=OFF
Invoke-Checked cmake --build $build --parallel 4

# (the files the CI's "Prepare build artifacts" step collects)
$out = Join-Path $work 'out'
New-Item -ItemType Directory -Path $out -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $build 'qbittorrent.exe') -Destination $out
Copy-Item -LiteralPath (Join-Path $src 'dist\windows\qt.conf') -Destination $out
foreach ($dll in 'Core', 'Gui', 'Network', 'Sql', 'Svg', 'Widgets', 'Xml') { Copy-Item -LiteralPath (Join-Path $qtDir "bin\Qt6$dll.dll") -Destination $out }
$plugins = 'iconengines\qsvgicon', 'imageformats\qgif', 'imageformats\qicns', 'imageformats\qico', 'imageformats\qjpeg', 'imageformats\qsvg',
    'imageformats\qtga', 'imageformats\qtiff', 'imageformats\qwbmp', 'imageformats\qwebp', 'platforms\qwindows', 'sqldrivers\qsqlite',
    'styles\qmodernwindowsstyle', 'tls\qschannelbackend'
foreach ($p in $plugins) {
    $from = Join-Path $qtDir "plugins\$p.dll"
    if (-not (Test-Path -LiteralPath $from)) { Say "(Qt $qtVer has no plugins\$p.dll)"; continue }
    New-Item -ItemType Directory -Path (Join-Path $out "plugins\$(Split-Path -Parent $p)") -Force | Out-Null
    Copy-Item -LiteralPath $from -Destination (Join-Path $out "plugins\$p.dll")
}
Publish-Build -From $out -Arch 'x64' -Version $ver -Note "Source: https://github.com/$repo, tag $tag (MSVC; libtorrent $ltVer, Boost $boostVer, Qt $qtVer)"
Complete-Build