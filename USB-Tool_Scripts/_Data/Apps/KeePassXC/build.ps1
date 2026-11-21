param([string]$Version, [string]$WorkDir, [switch]$KeepWork, [switch]$Yes)
. "$PSScriptRoot\..\_Build-App.ps1"
trap { Stop-Build $_ }

# Builds KeePassXC from source (github.com/keepassxreboot/keepassxc) into Built\x64 (and Built\ARM64), the way its
# release-tool.py builds the Windows release: CMake + Ninja with MSVC, its dependencies (Botan, minizip, libqrencode,
# readline, zlib) from vcpkg at the vcpkg.json's builtin-baseline (x64-windows triplet, copied beside the exe), and Qt 6
# (the version that vcpkg baseline has) from download.qt.io; "cmake --install" lays it out like the release zip
# (KeePassXC.exe, keepassxc-cli.exe, keepassxc-proxy.exe, the Qt and other DLLs windeployqt / vcpkg copy, share\).
# Differences: no offline user guide (KPXC_FEATURE_DOCS=OFF: it needs asciidoctor / Ruby) and not code-signed.
# ARM64 is built only when Visual Studio has its ARM64 C++ tools (Microsoft.VisualStudio.Component.VC.Tools.ARM64).
# Needs: Visual Studio 2022 with C++, CMake; vcpkg, Qt (aqtinstall, with a portable Python) and Ninja, downloaded into
# the tools folder when missing
# Usage: build.cmd [-Version <x.y.z>] [-KeepWork] [-WorkDir <folder>]

$repo = 'keepassxreboot/keepassxc'
$tag = if ($Version) { $Version -replace '^v' } else { Get-LatestGitHubTag $repo }
$work = Start-Build -Name 'KeePassXC' -NeedGB 8
$src = Join-Path $work 'src'
Get-GitSource "https://github.com/$repo.git" $tag $src
if (-not (Get-Command cmake.exe -ErrorAction SilentlyContinue)) { throw 'This build needs CMake (cmake.org) on the PATH' }

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
$manifest = Get-Content -LiteralPath (Join-Path $src 'vcpkg.json') -Raw | ConvertFrom-Json
$vcpkg = Use-Vcpkg $manifest.'builtin-baseline'
# (the Qt version vcpkg's baseline would build, from download.qt.io instead)
$qtVer = (Get-Content -LiteralPath (Join-Path $vcpkg 'ports\qtbase\vcpkg.json') -Raw | ConvertFrom-Json).version
Use-Tool ninja
$env:MSBUILDDISABLENODEREUSE = '1'

$env:PATH = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer;$env:PATH"
$cleanEnv = @{}; Get-ChildItem Env: | ForEach-Object { $cleanEnv[$_.Name] = $_.Value }
function Reset-Env { Get-ChildItem Env: | Where-Object { -not $cleanEnv.ContainsKey($_.Name) } | ForEach-Object { Remove-Item -LiteralPath "Env:$($_.Name)" }; foreach ($k in $cleanEnv.Keys) { Set-Item -LiteralPath "Env:$k" -Value $cleanEnv[$k] } }
function Test-VSComponent([string[]]$Components) {
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    return [bool](& $vswhere -version '[17.0,18.0)' -products * -requires $Components -property installationPath)
}

foreach ($arch in @(
        @{ VS = 'x64'; Folder = 'x64'; Triplet = 'x64-windows'; Qt = 'win64_msvc2022_64' },
        @{ VS = 'arm64'; Folder = 'ARM64'; Triplet = 'arm64-windows'; Qt = 'win64_msvc2022_arm64_cross_compiled'; Needs = 'Microsoft.VisualStudio.Component.VC.Tools.ARM64' })) {
    if ($arch.Needs -and -not (Test-VSComponent $arch.Needs)) { Say "Skipping $($arch.Folder): Visual Studio 2022 doesn't have $($arch.Needs)"; continue }
    Reset-Env
    # (the ARM64 Qt is cross-compiled: its tools run from the x64 Qt)
    $hostQt = if ($arch.Folder -ne 'x64') { Use-Qt -Version $qtVer -Arch 'win64_msvc2022_64' -Modules 'qtimageformats' }
    $qtDir = Use-Qt -Version $qtVer -Arch $arch.Qt -Modules 'qtimageformats'
    Use-VisualStudio -Arch $arch.VS -Version '[17.0,18.0)' -Components (@('Microsoft.VisualStudio.Component.VC.Tools.x86.x64') + @($arch.Needs | Where-Object { $_ })) | Out-Null
    Say "Building KeePassXC $tag for $($arch.Folder) (Qt $qtVer)..."
    $build = Join-Path $work "build-$($arch.Folder)"
    $out = Join-Path $work "out\$($arch.Folder)"
    $cmakeArgs = @('-S', $src, '-B', $build, '-G', 'Ninja',
        "-DVCPKG_TARGET_TRIPLET=$($arch.Triplet)", "-DCMAKE_TOOLCHAIN_FILE=$vcpkg\scripts\buildsystems\vcpkg.cmake",
        '-DCMAKE_BUILD_TYPE=Release', "-DCMAKE_INSTALL_PREFIX=$out", "-DCMAKE_PREFIX_PATH=$qtDir",
        '-DWITH_TESTS=OFF', '-DWITH_GUI_TESTS=OFF', '-DKPXC_MINIMAL=OFF', '-DKEEPASSXC_BUILD_TYPE=Release',
        '-DKPXC_FEATURE_DOCS=OFF', '-DX_VCPKG_APPLOCAL_DEPS_INSTALL=ON')
    if ($hostQt) { $cmakeArgs += "-DQT_HOST_PATH=$hostQt" }
    Invoke-Checked cmake @cmakeArgs
    Invoke-Checked cmake --build $build --parallel 4
    Invoke-Checked cmake --install $build
    Publish-Build -From $out -Arch $arch.Folder -Version $tag -Note "Source: https://github.com/$repo, tag $tag (MSVC, vcpkg $($manifest.'builtin-baseline'), Qt $qtVer)"
}
Complete-Build