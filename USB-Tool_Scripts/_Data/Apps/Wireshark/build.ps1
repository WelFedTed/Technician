param([string]$Version, [string]$WorkDir, [switch]$KeepWork, [switch]$Yes)
. "$PSScriptRoot\..\_Build-App.ps1"
trap { Stop-Build $_ }

# Builds Wireshark from source (gitlab.com/wireshark/wireshark) into Built\x64, the way its CI's "Windows x64
# Package" job (.gitlab-ci.yml) does: tools\make-version.py --set-release, CMake with ENABLE_LTO=OFF and MSVC,
# RelWithDebInfo, with Qt (the CI's WINDOWS_QT_VERSION, with qt5compat and qtmultimedia, from aqtinstall like the CI)
# and the prebuilt libraries CMake downloads itself (wireshark-x64-libs, kept in the tools folder); the result is
# the run folder the installer and the portable package are made from (Wireshark.exe, tshark.exe, dumpcap.exe, the
# other tools, DLLs, plugins, extcap, Qt).
# Differences: Visual Studio 2022 and Ninja (the CI uses Visual Studio 2026's generator); not signed; no Stratoshark;
# no Npcap / USBPcap (the installer bundles those drivers); no manuals unless xsltproc is found. ARM64 isn't built
# (the CI builds it natively on an ARM64 machine).
# Needs: Visual Studio 2022 with C++, CMake, Git; Python, Qt (aqtinstall), WinFlexBison and Ninja, downloaded into
# the tools folder when missing
# Usage: build.cmd [-Version <x.y.z>] [-KeepWork] [-WorkDir <folder>]

$repoUrl = 'https://gitlab.com/wireshark/wireshark.git'
if ($Version) { $ver = $Version -replace '^v' }
else {
    # (the newest version on the download page update.cmd uses)
    $page = Get-Text 'https://www.wireshark.org/download/win64/'
    $ver = [regex]::Matches($page, 'Wireshark-([\d.]+)-x64\.exe') | ForEach-Object { $_.Groups[1].Value } | Sort-Object { [version]$_ } | Select-Object -Last 1
    if (-not $ver) { throw "Couldn't find the latest version on wireshark.org" }
}
$tag = "v$ver"
$work = Start-Build -Name 'Wireshark' -NeedGB 10
$src = Join-Path $work 'src'
$env:GIT_CONFIG_COUNT = '1'; $env:GIT_CONFIG_KEY_0 = 'core.longpaths'; $env:GIT_CONFIG_VALUE_0 = 'true'
Get-GitSource $repoUrl $tag $src
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

# (the Qt version and modules the CI installs)
$ci = [IO.File]::ReadAllText((Join-Path $src '.gitlab-ci.yml'))
$m = [regex]::Match($ci, 'WINDOWS_QT_VERSION:\s*"([\d.]+)"'); $qtVer = if ($m.Success) { $m.Groups[1].Value } else { '6.10.3' }
$qtDir = Use-Qt -Version $qtVer -Arch 'win64_msvc2022_64' -Modules 'qt5compat', 'qtmultimedia'
Use-Tool python -Version '3.6'
Use-Tool ninja

# WinFlexBison (win_flex / win_bison), from its GitHub releases
$flexDir = Join-Path $script:toolsDir 'winflexbison'
if (-not (Test-Path -LiteralPath "$flexDir\win_flex.exe")) {
    $rel = Get-Text 'https://api.github.com/repos/lexxmark/winflexbison/releases/latest' | ConvertFrom-Json
    $asset = $rel.assets | Where-Object { $_.name -match '^win_flex_bison-[\d.]+\.zip$' } | Select-Object -First 1
    if (-not $asset) { throw "Couldn't find WinFlexBison's zip in its latest release" }
    $zip = Join-Path $script:toolsDir $asset.name
    Get-File $asset.browser_download_url $zip
    [IO.Compression.ZipFile]::ExtractToDirectory($zip, $flexDir); Remove-Item -LiteralPath $zip
}
Add-ToPath $flexDir

# (CMake downloads Wireshark's prebuilt Windows libraries into WIRESHARK_BASE_DIR; kept with the other tools)
$env:WIRESHARK_BASE_DIR = Join-Path $script:toolsDir 'wireshark'
New-Item -ItemType Directory -Path $env:WIRESHARK_BASE_DIR -Force | Out-Null
$env:PATH = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer;$env:PATH"
Use-VisualStudio -Arch x64 -Version '[17.0,18.0)' | Out-Null
$env:CMAKE_PREFIX_PATH = $qtDir

$build = Join-Path $work 'build'
New-Item -ItemType Directory -Path $build -Force | Out-Null
Push-Location -LiteralPath $build
try {
    Invoke-Checked python (Join-Path $src 'tools\make-version.py') --set-release '--wireshark-version-file=wireshark_version.txt' $src
    Say "Building Wireshark $ver for x64 (Qt $qtVer)..."
    Invoke-Checked cmake -S $src -B $build -G Ninja -DCMAKE_BUILD_TYPE=RelWithDebInfo -DENABLE_LTO=OFF -DBUILD_stratoshark=OFF
    Invoke-Checked cmake --build $build --parallel 4
}
finally { Pop-Location }
$run = Join-Path $build 'run'
if (-not (Test-Path -LiteralPath (Join-Path $run 'Wireshark.exe'))) { throw "The build didn't make $run\Wireshark.exe" }
# (the debug symbols and test programs aren't part of the release)
Get-ChildItem -LiteralPath $run -Recurse -File | Where-Object { $_.Extension -in '.pdb', '.ilk', '.exp' } | Remove-Item
Publish-Build -From $run -Arch 'x64' -Version $ver -Note "Source: $repoUrl, tag $tag (MSVC, RelWithDebInfo, Qt $qtVer)"
Complete-Build