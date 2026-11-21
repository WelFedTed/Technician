param([string]$Version, [string]$WorkDir, [switch]$KeepWork, [switch]$Yes)
. "$PSScriptRoot\..\_Build-App.ps1"
trap { Stop-Build $_ }

# Builds AntiMicroX from source (github.com/AntiMicroX/antimicrox) into Built\x64, the way its release workflow
# (.github/workflows/release.yml, job build-windows-packages) builds the portable zip: MSYS2 mingw64 (toolchain,
# Ninja, OpenSSL, CMake), the SDL2 package that workflow pins (installed with pacman -U), Qt 6 for MinGW 64-bit
# (win64_mingw, which the workflow gets with install-qt-action / aqtinstall), then CMake with PORTABLE_WIN=ON and
# its package target, whose ZIP (antimicrox-<ver>-PortableWindows-AMD64.zip) is unpacked into Built\x64:
# bin\antimicrox.exe with its Qt / SDL2 / OpenSSL / MinGW DLLs and bin\platforms\qwindows.dll, and share\antimicrox
# (the controller database and translations). PORTABLE_WIN makes it keep its settings next to the program.
# Difference: MSYS2 has since moved to OpenSSL 4, so the OpenSSL 3 DLLs the zip has come from MSYS2's newest 3.x
# package (as the official zip's did); the build is unsigned, like the official one.
# Needs: a portable MSYS2 (with those packages), Qt for MinGW (aqtinstall, with a portable Python), both downloaded
# into the tools folder when missing
# Usage: build.cmd [-Version <x.y.z>] [-KeepWork] [-WorkDir <folder>]

$repo = 'AntiMicroX/antimicrox'
$tag = if ($Version) { $Version -replace '^v' } else { Get-LatestGitHubTag $repo }
$ver = $tag -replace '^v'
$work = Start-Build -Name 'AntiMicroX' -NeedGB 5
$src = Join-Path $work 'src'
Get-GitSource "https://github.com/$repo.git" $tag $src

# (the SDL2 package and the Qt version the release workflow uses, eg. mingw-w64-x86_64-SDL2-2.32.10-1-any.pkg.tar.zst
# from mirror.msys2.org and Qt "6.10", which is that minor version's newest release)
$workflow = [IO.File]::ReadAllText((Join-Path $src '.github\workflows\release.yml'))
$m = [regex]::Match($workflow, '(https://mirror\.msys2\.org/mingw/mingw64/)(mingw-w64-x86_64-SDL2-[^\s/]+\.pkg\.tar\.zst)')
$sdlUrl = if ($m.Success) { $m.Value } else { 'https://mirror.msys2.org/mingw/mingw64/mingw-w64-x86_64-SDL2-2.32.10-1-any.pkg.tar.zst' }
$m = [regex]::Match($workflow, '(?s)build-windows-packages:.*?install-qt-action.*?version:\s*"?([\d.]+)"?')
$qtSpec = if ($m.Success) { $m.Groups[1].Value } else { '6.10' }

# Qt from download.qt.io with aqtinstall (in a venv), kept in the tools folder (Qt\<version>\<arch folder>), so the
# next build doesn't download it again; adds its bin folder to the PATH and returns the Qt folder
# (-Arch: aqt's name, eg. win64_msvc2022_64, win32_msvc2019, win64_mingw; -Modules: aqt's add-on module names;
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
# the newest Qt release of a minor version (eg. 6.10 > 6.10.3), from aqt's list of what download.qt.io has
function Resolve-QtVersion([string]$Spec, [string]$Arch) {
    if ($Spec -match '^\d+\.\d+\.\d+$') { return $Spec }
    $aqtPy = Get-Aqt
    Push-Location -LiteralPath $script:toolsDir
    try {
        # (Continue: aqt logs to stderr, which would stop the build otherwise)
        $ErrorActionPreference = 'Continue'
        $out = & $aqtPy -m aqt list-qt windows desktop --spec $Spec --arch-filter $Arch --latest-version 2>$null | Out-String
        if ($LASTEXITCODE -ne 0) { $out = & $aqtPy -m aqt list-qt windows desktop --spec $Spec --latest-version 2>$null | Out-String }
    }
    finally { Pop-Location }
    $found = [regex]::Match("$out", '\d+\.\d+\.\d+')
    if (-not $found.Success) { throw "Couldn't find a Qt $Spec release (aqt list-qt)" }
    return $found.Value
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

# MSYS2 mingw64 with the workflow's packages (not NSIS, which only the installer needs), then its pinned SDL2
# (AntiMicroX issue #465: newer SDL2 packages broke it), unless that one is installed already
Use-Msys2 -Packages @('mingw-w64-x86_64-toolchain', 'mingw-w64-x86_64-ninja', 'mingw-w64-x86_64-openssl', 'mingw-w64-x86_64-cmake')
$sdlFile = $sdlUrl -replace '^.*/'
$sdlWanted = $sdlFile -replace '^(mingw-w64-x86_64-SDL2)-(.+)-any\.pkg\.tar\.zst$', '$1 $2'
$sdlPkg = Join-Path $work "pkg\$sdlFile"
Get-File $sdlUrl $sdlPkg
Say "Installing $sdlFile (the SDL2 the release workflow pins)..."
Invoke-Msys2 -Env msys -Dir $script:toolsDir -Command "if [ `"`$(pacman -Q mingw-w64-x86_64-SDL2 2>/dev/null)`" != '$sdlWanted' ]; then pacman --noconfirm -U `"`$(cygpath -u '$sdlPkg')`"; fi"

# (CHECK_FOR_UPDATES ships OpenSSL 3's libcrypto-3-x64.dll / libssl-3-x64.dll, the only names AntiMicroX's
# CMakeLists looks for; when MSYS2 has moved on to a newer OpenSSL, those two come from its newest 3.x package,
# unpacked into the work folder rather than installed, since MSYS2's own curl / CMake use the newer one)
$sslArgs = ''
if (-not (Test-Path -LiteralPath (Join-Path $script:msysDir 'mingw64\bin\libcrypto-3-x64.dll'))) {
    $listing = Get-Text 'https://repo.msys2.org/mingw/mingw64/'
    $ssl3 = [regex]::Matches($listing, 'mingw-w64-x86_64-openssl-(3\.[\d.]+)-(\d+)-any\.pkg\.tar\.zst(?=")') |
        Sort-Object { [version]$_.Groups[1].Value }, { [int]$_.Groups[2].Value } | Select-Object -Last 1
    if (-not $ssl3) { throw "Couldn't find an OpenSSL 3 package on repo.msys2.org" }
    Say "MSYS2's OpenSSL isn't 3.x, so the OpenSSL 3 DLLs come from $($ssl3.Value)..."
    $sslDir = Join-Path $work 'openssl3'
    Get-File "https://repo.msys2.org/mingw/mingw64/$($ssl3.Value)" (Join-Path $sslDir $ssl3.Value)
    Invoke-Msys2 -Env msys -Dir $sslDir -Command "tar -xf '$($ssl3.Value)' mingw64/bin/libcrypto-3-x64.dll mingw64/bin/libssl-3-x64.dll"
    $sslArgs = "'-DLIBCRYPTO_DLL_FILE=$("$sslDir\mingw64\bin\libcrypto-3-x64.dll" -replace '\\', '/')' '-DLIBSSL_DLL_FILE=$("$sslDir\mingw64\bin\libssl-3-x64.dll" -replace '\\', '/')'"
}

$qtVer = Resolve-QtVersion $qtSpec 'win64_mingw'
$qtDir = Use-Qt -Version $qtVer -Arch 'win64_mingw'

Say "Building AntiMicroX $ver for x64 (MSYS2 mingw64, Qt $qtVer MinGW, $($sdlWanted -replace '^mingw-w64-x86_64-'))..."
$build = Join-Path $work 'build'
$fwd = { param($p) $p -replace '\\', '/' }
Invoke-Msys2 -Env mingw64 -Dir $work -Command @"
set -e
export CMAKE_PREFIX_PATH='$(& $fwd "$qtDir\lib\cmake")'
cmake -G Ninja -S '$(& $fwd $src)' -B '$(& $fwd $build)' -DCMAKE_BUILD_TYPE=Release -DCHECK_FOR_UPDATES=ON "-DANTIMICROX_PKG_VERSION=GitHub Portable Windows Release" -DPORTABLE_WIN=ON $sslArgs
cmake --build '$(& $fwd $build)' --target package --parallel 4
"@

# (the package target's ZIP has one folder, antimicrox-<ver>-PortableWindows-AMD64, with bin and share in it)
$zip = Get-ChildItem -LiteralPath $build -Filter 'antimicrox-*-PortableWindows-*.zip' | Select-Object -First 1
if (-not $zip) { throw "The build didn't make $build\antimicrox-$ver-PortableWindows-AMD64.zip" }
$unpacked = Join-Path $work 'package'
Expand-Archive7 $zip.FullName $unpacked
$top = Join-Path $unpacked $zip.BaseName
if (-not (Test-Path -LiteralPath (Join-Path $top 'bin\antimicrox.exe'))) { throw "$($zip.Name) has no $($zip.BaseName)\bin\antimicrox.exe" }
Publish-Build -From $top -Arch 'x64' -Version $ver -Note "Source: https://github.com/$repo, tag $tag (portable zip: MSYS2 mingw64, Qt $qtVer win64_mingw, $($sdlWanted -replace '^mingw-w64-x86_64-'), PORTABLE_WIN=ON)"
Complete-Build
