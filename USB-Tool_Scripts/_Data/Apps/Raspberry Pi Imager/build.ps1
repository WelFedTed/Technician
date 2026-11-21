param([string]$Version, [string]$WorkDir, [switch]$KeepWork, [switch]$Yes)
. "$PSScriptRoot\..\_Build-App.ps1"
trap { Stop-Build $_ }

# Builds Raspberry Pi Imager from source (github.com/raspberrypi/rpi-imager) into Built\x64, the way its BUILDING.md
# builds it on Windows: CMake (src\CMakeLists.txt, MinSizeRel) with Qt 6.11 for MinGW 64-bit and Qt's MinGW 13.1,
# building the rpi-imager target, whose post-build step lays out build\deploy with windeployqt (rpi-imager.exe,
# rpi-imager-callback-relay.exe, rpi-imager-cli.cmd, the WinUSB .inf, the Qt DLLs and QML) - what the installer ships.
# Differences: the official download is the (signed) Inno Setup installer; this is the folder it installs, unsigned.
# Needs: CMake; Qt 6 for MinGW and Qt's MinGW (aqtinstall, with a portable Python) and Ninja, downloaded into the
# tools folder when missing
# Usage: build.cmd [-Version <x.y.z>] [-KeepWork] [-WorkDir <folder>]

$repo = 'raspberrypi/rpi-imager'
$tag = if ($Version) { 'v' + ($Version -replace '^v') } else { Get-LatestGitHubTag $repo }
$ver = $tag -replace '^v'
# (windres, which compiles the .rc file, can't take include paths with spaces, so the work folder is named rpi-imager)
$work = Start-Build -Name 'rpi-imager' -NeedGB 6
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

# a Qt MinGW compiler (aqt's tools_mingw / tools_mingw1310..., eg. qt.tools.win32_mingw810 > Qt\Tools\mingw810_32), on the PATH
function Use-QtMinGW([string]$Package = 'qt.tools.win32_mingw810', [string]$Folder = 'mingw810_32', [string]$Tool = 'tools_mingw') {
    $dir = Join-Path $script:toolsDir "Qt\Tools\$Folder"
    if (-not (Test-Path -LiteralPath "$dir\bin\g++.exe")) {
        Say "Getting Qt's MinGW ($Folder)..."
        Invoke-Aqt @('install-tool', 'windows', 'desktop', $Tool, $Package, '--outputdir', (Join-Path $script:toolsDir 'Qt'))
    }
    Add-ToPath "$dir\bin"
}

# (the Qt and MinGW versions BUILDING.md names, eg. -DQt6_ROOT=C:\Qt\6.11.2\mingw_64, -DMINGW64_ROOT=C:\Qt\Tools\mingw1310_64)
$doc = [IO.File]::ReadAllText((Join-Path $src 'BUILDING.md'))
$m = [regex]::Match($doc, 'Qt6_ROOT=C:\\Qt\\([\d.]+)\\mingw_64'); $qtVer = if ($m.Success) { $m.Groups[1].Value } else { '6.11.2' }
$m = [regex]::Match($doc, 'MINGW64_ROOT=C:\\Qt\\Tools\\(mingw(\d+)_64)'); $mingw = if ($m.Success) { $m.Groups[1].Value } else { 'mingw1310_64' }
$qtDir = Use-Qt -Version $qtVer -Arch 'win64_mingw'
Use-QtMinGW -Package "qt.tools.win64_$($mingw -replace '_64$')" -Folder $mingw -Tool "tools_$($mingw -replace '_64$')"
$mingwDir = Join-Path $script:toolsDir "Qt\Tools\$mingw"
Use-Tool ninja

Say "Building Raspberry Pi Imager $ver for x64 (Qt $qtVer, $mingw)..."
$build = Join-Path $work 'build'
Invoke-Checked cmake -S (Join-Path $src 'src') -B $build -G Ninja -DCMAKE_BUILD_TYPE=MinSizeRel "-DQt6_ROOT=$qtDir" "-DMINGW64_ROOT=$mingwDir" `
    "-DCMAKE_C_COMPILER=$mingwDir\bin\gcc.exe" "-DCMAKE_CXX_COMPILER=$mingwDir\bin\g++.exe" -DIMAGER_SIGNED_APP=OFF
Invoke-Checked cmake --build $build --target rpi-imager --parallel 4
$deploy = Join-Path $build 'deploy'
if (-not (Test-Path -LiteralPath (Join-Path $deploy 'rpi-imager.exe'))) { throw "The build didn't make $deploy\rpi-imager.exe" }
Publish-Build -From $deploy -Arch 'x64' -Version $ver -Note "Source: https://github.com/$repo, tag $tag (Qt $qtVer MinGW, $mingw, MinSizeRel)"
Complete-Build