param([string]$Version, [string]$WorkDir, [switch]$KeepWork, [switch]$Yes)
. "$PSScriptRoot\..\_Build-App.ps1"
trap { Stop-Build $_ }

# Builds OpenRGB from source (gitlab.com/CalcProgrammer1/OpenRGB) into Built\x64 and Built\x86, the way its CI
# (.gitlab-ci.yml) runs scripts\build-windows.bat: qmake OpenRGB.pro CONFIG+=release and jom with MSVC, then
# windeployqt with the same options, plus the dependency DLLs and PawnIO modules OpenRGB.pro copies (from the repo's
# dependencies folder), like the official "OpenRGB Windows 64-bit" / "32-bit" zips.
# x64 uses Qt 6.8.3 (msvc2022_64) like the CI; x86 uses Qt 5.15.2 (msvc2019), like the CI's "Windows 32 Qt5" job,
# since the Qt Company has no 32-bit Qt 6 (the CI's own 32-bit Qt 6 comes from OpenRGB-Qt-Packages).
# Needs: Visual Studio 2022 with C++; Qt (aqtinstall, with a portable Python) and jom, downloaded into the tools
# folder when missing
# Usage: build.cmd [-Version <x.y>] [-KeepWork] [-WorkDir <folder>]

$tag = if ($Version) { 'release_' + ($Version -replace '^release_') } else { Get-LatestGitHubTag 'CalcProgrammer1/OpenRGB' }
$ver = $tag -replace '^release_(candidate_)?'
$work = Start-Build -Name 'OpenRGB' -NeedGB 6
$src = Join-Path $work 'src'
$env:GIT_CONFIG_COUNT = '1'; $env:GIT_CONFIG_KEY_0 = 'core.longpaths'; $env:GIT_CONFIG_VALUE_0 = 'true'
Get-GitSource 'https://gitlab.com/CalcProgrammer1/OpenRGB.git' $tag $src

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

# jom (nmake with parallel jobs), from download.qt.io
$jomDir = Join-Path $script:toolsDir 'jom'
if (-not (Test-Path -LiteralPath "$jomDir\jom.exe")) {
    $zip = Join-Path $script:toolsDir 'jom.zip'
    Get-File 'https://download.qt.io/official_releases/jom/jom.zip' $zip
    [IO.Compression.ZipFile]::ExtractToDirectory($zip, $jomDir); Remove-Item -LiteralPath $zip
}
$env:MSBUILDDISABLENODEREUSE = '1'

$env:PATH = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer;$env:PATH"
$cleanEnv = @{}; Get-ChildItem Env: | ForEach-Object { $cleanEnv[$_.Name] = $_.Value }
function Reset-Env { Get-ChildItem Env: | Where-Object { -not $cleanEnv.ContainsKey($_.Name) } | ForEach-Object { Remove-Item -LiteralPath "Env:$($_.Name)" }; foreach ($k in $cleanEnv.Keys) { Set-Item -LiteralPath "Env:$k" -Value $cleanEnv[$k] } }

foreach ($arch in @(
        @{ VS = 'x64'; Folder = 'x64'; Bits = 64; QtVer = '6.8.3'; Qt = 'win64_msvc2022_64'; Modules = @('qt5compat') },
        @{ VS = 'x86'; Folder = 'x86'; Bits = 32; QtVer = '5.15.2'; Qt = 'win32_msvc2019'; Modules = @() })) {
    Reset-Env
    $qtDir = Use-Qt -Version $arch.QtVer -Arch $arch.Qt -Modules $arch.Modules
    Add-ToPath $jomDir
    Use-VisualStudio -Arch $arch.VS -Version '[17.0,18.0)' | Out-Null
    Say "Building OpenRGB $ver for $($arch.Folder) (Qt $($arch.QtVer))..."
    # (qmake builds in the source folder, like the CI; it's cleaned between architectures)
    Invoke-Checked (Get-Git) -C $src clean -fdxq
    $build = $src
    Push-Location -LiteralPath $build
    try {
        Invoke-Checked qmake.exe OpenRGB.pro 'CONFIG-=debug_and_release' 'CONFIG+=release'
        Invoke-Checked jom.exe /J 4
        Invoke-Checked windeployqt.exe --no-patchqt --no-quick-import --no-translations --no-system-d3d-compiler --no-compiler-runtime --no-opengl-sw --no-network .\release\
        if ($arch.QtVer -like '6*') { foreach ($dll in 'Qt6Core5Compat.dll', 'Qt6OpenGL.dll') { Copy-Item -LiteralPath (Join-Path $qtDir "bin\$dll") -Destination .\release\ } }
    }
    finally { Pop-Location }
    $out = Join-Path $work "out\$($arch.Folder)"
    New-Item -ItemType Directory -Path (Join-Path $work 'out') -Force | Out-Null
    Move-Item -LiteralPath (Join-Path $build 'release') -Destination $out
    # (the build's intermediate files aren't in the official zip)
    Get-ChildItem -LiteralPath $out -File | Where-Object { $_.Extension -in '.obj', '.pch', '.res', '.cpp', '.h', '.qm' } | Remove-Item
    Publish-Build -From $out -Arch $arch.Folder -Version $ver -Note "Source: https://gitlab.com/CalcProgrammer1/OpenRGB, tag $tag (MSVC, Qt $($arch.QtVer))"
}
Complete-Build