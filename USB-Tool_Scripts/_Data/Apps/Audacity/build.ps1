param([string]$Version, [string]$WorkDir, [switch]$KeepWork, [switch]$Yes)
. "$PSScriptRoot\..\_Build-App.ps1"
trap { Stop-Build $_ }

# Builds Audacity 4 from source (github.com/audacity/audacity, with its muse framework submodules) into Built\x64,
# the way its Windows CI (.github/workflows/au4_build_windows.yml > ci_build.bat / ci_build.cmake) does: Qt 6 (the
# CI's version and add-on modules, from download.qt.io with aqtinstall like the CI's install-qt-action), CMake +
# Ninja with MSVC, RelWithDebInfo, AU4_BUILD_MODE=release, then "cmake --install" - the folder the installer ships
# (bin\Audacity4.exe with its Qt DLLs, QML and plugins).
# Differences: no crash reporter (the CI's needs Audacity's Sentry keys); not signed; no .pdb files. ARM64 isn't
# built (the CI builds it natively on an ARM64 machine).
# Needs: Visual Studio 2022 with C++, CMake, Git; Qt (aqtinstall, with a portable Python) and Ninja, downloaded into
# the tools folder when missing
# Usage: build.cmd [-Version <x.y.z>] [-KeepWork] [-WorkDir <folder>]

$repo = 'audacity/audacity'
$tag = if ($Version) { 'Audacity-' + ($Version -replace '^Audacity-') } else { Get-LatestGitHubTag $repo }
$ver = $tag -replace '^Audacity-'
$work = Start-Build -Name 'Audacity' -NeedGB 12
$src = Join-Path $work 'src'
$env:GIT_CONFIG_COUNT = '1'; $env:GIT_CONFIG_KEY_0 = 'core.longpaths'; $env:GIT_CONFIG_VALUE_0 = 'true'
Get-GitSource "https://github.com/$repo.git" $tag $src -Submodules
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

# (the Qt version and modules the CI's "Install Qt" step uses)
$ci = [IO.File]::ReadAllText((Join-Path $src '.github\workflows\au4_build_windows.yml'))
$m = [regex]::Match($ci, "install-qt-action@\S+\s+with:[\s\S]*?version: '([\d.]+)'[\s\S]*?modules: '([^']+)'")
if ($m.Success) { $qtVer = $m.Groups[1].Value; $modules = $m.Groups[2].Value -split '\s+' | Where-Object { $_ } }
else { $qtVer = '6.10.1'; $modules = 'qt5compat', 'qtnetworkauth', 'qtshadertools', 'qtwebsockets', 'qtgraphs', 'qtquick3d' }
# (BUILDING.md also lists Qt State Machines)
if ($modules -notcontains 'qtscxml') { $modules += 'qtscxml' }
$qtDir = Use-Qt -Version $qtVer -Arch 'win64_msvc2022_64' -Modules $modules
Use-Tool ninja
$env:PATH = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer;$env:PATH"
Use-VisualStudio -Arch x64 -Version '[17.0,18.0)' | Out-Null

Say "Building Audacity $ver for x64 (Qt $qtVer)..."
# (a short build folder name: some of muse's generated QML plugin object files have paths of over 200 characters,
# and the compiler can't write past Windows' 260-character limit)
$build = Join-Path $work 'b'
$install = Join-Path $work 'build.install'
Invoke-Checked cmake -S $src -B $build -G Ninja -DCMAKE_BUILD_TYPE=RelWithDebInfo "-DCMAKE_PREFIX_PATH=$qtDir" "-DCMAKE_INSTALL_PREFIX=$install" `
    -DAU4_BUILD_MODE=release -DAU4_BUILD_CONFIGURATION=app -DMUSE_ENABLE_UNIT_TESTS=OFF -DMUSE_MODULE_DIAGNOSTICS_CRASHPAD_CLIENT=OFF
# (a compiler hiccup on one of the ~3000 files, eg. C1083 on a temporary file, is worth a second go; Ninja carries on where it stopped)
& cmake --build $build --parallel 4
if ($LASTEXITCODE -ne 0) { Say 'The build failed; trying once more (it carries on where it stopped)...'; Invoke-Checked cmake --build $build --parallel 4 }
Invoke-Checked cmake --install $build
if (-not (Test-Path -LiteralPath (Join-Path $install 'bin\Audacity4.exe'))) { throw "The build didn't make $install\bin\Audacity4.exe" }
Get-ChildItem -LiteralPath $install -Recurse -Filter '*.pdb' -File | Remove-Item
Publish-Build -From $install -Arch 'x64' -Version $ver -Note "Source: https://github.com/$repo, tag $tag (MSVC, Ninja, RelWithDebInfo, Qt $qtVer)"
Complete-Build