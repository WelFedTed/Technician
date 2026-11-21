param([string]$Version, [string]$WorkDir, [switch]$KeepWork, [switch]$Yes)
. "$PSScriptRoot\..\_Build-App.ps1"
trap { Stop-Build $_ }

# Builds Ext2Explore (Ext2Read) from source (github.com/mregmi/ext2read) into Built\x86, the way its README says to
# build it on Windows: qmake ext2explore.pro and mingw32-make with Qt 5 and Qt's 32-bit MinGW; ext2explore.exe with
# the Qt DLLs it needs beside it (windeployqt).
# Differences: the official download (2.2.71) is a single exe built from an older Qt; the project has no release tag
# after ext2read2.2, so this builds its master branch (the newest source) unless -Version picks a tag (eg. 2.2).
# Needs: Qt 5.15 for MinGW 32-bit and Qt's MinGW 8.1, downloaded into the tools folder with aqtinstall (which needs
# a portable Python, downloaded when missing)
# Usage: build.cmd [-Version <x.y>] [-KeepWork] [-WorkDir <folder>]

$repo = 'mregmi/ext2read'
$ref = if ($Version) { 'ext2read' + ($Version -replace '^ext2read') } else { 'master' }
$work = Start-Build -Name 'Ext2Explore' -NeedGB 1
$src = Join-Path $work 'src'
Get-GitSource "https://github.com/$repo.git" $ref $src
$commit = (& (Get-Git) -C $src rev-parse --short HEAD | Out-String).Trim()
$ver = if ($Version) { $Version -replace '^ext2read' } else { "master-$commit" }

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

$qtDir = Use-Qt -Version '5.15.2' -Arch 'win32_mingw81'
Use-QtMinGW -Package 'qt.tools.win32_mingw810' -Folder 'mingw810_32'

Say "Building Ext2Explore $ver for x86..."
$build = Join-Path $work 'build'
New-Item -ItemType Directory -Path $build -Force | Out-Null
Push-Location -LiteralPath $build
try {
    Invoke-Checked qmake.exe (Join-Path $src 'ext2explore.pro') 'CONFIG+=release' 'CONFIG-=debug_and_release'
    Invoke-Checked mingw32-make.exe -j4
}
finally { Pop-Location }
$exe = Get-ChildItem -LiteralPath $build -Recurse -Filter 'ext2explore.exe' | Select-Object -First 1
if (-not $exe) { throw "The build didn't make ext2explore.exe" }
$out = Join-Path $work 'out'
New-Item -ItemType Directory -Path $out -Force | Out-Null
Copy-Item -LiteralPath $exe.FullName -Destination $out
# (the Qt and MinGW DLLs it needs; copied by hand, as Qt 5.15's windeployqt takes aqt's MinGW plugins for debug ones)
foreach ($dll in 'Qt5Core.dll', 'Qt5Gui.dll', 'Qt5Widgets.dll') { Copy-Item -LiteralPath (Join-Path $qtDir "bin\$dll") -Destination $out }
foreach ($plugin in 'platforms\qwindows.dll', 'styles\qwindowsvistastyle.dll', 'imageformats\qico.dll') {
    New-Item -ItemType Directory -Path (Join-Path $out (Split-Path -Parent $plugin)) -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $qtDir "plugins\$plugin") -Destination (Join-Path $out $plugin)
}
$gpp = (Get-Command g++.exe).Source
foreach ($dll in 'libgcc_s_dw2-1.dll', 'libstdc++-6.dll', 'libwinpthread-1.dll') { Copy-Item -LiteralPath (Join-Path (Split-Path -Parent $gpp) $dll) -Destination $out }
foreach ($f in 'LICENSE', 'README.md') { Copy-Item -LiteralPath (Join-Path $src $f) -Destination $out }
Publish-Build -From $out -Arch 'x86' -Version $ver -Note "Source: https://github.com/$repo, $ref ($commit) (Qt 5.15.2, MinGW 8.1 32-bit)"
Complete-Build
