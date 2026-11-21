param([string]$Version, [string]$WorkDir, [switch]$KeepWork, [switch]$Yes)
. "$PSScriptRoot\..\_Build-App.ps1"
trap { Stop-Build $_ }

# Builds the OpenVPN community client's installer (OpenVPN-<version>-I<nnn>-amd64.msi and -x86.msi, as update.cmd
# downloads) from source into Built\x64 and Built\x86 (and Built\ARM64 when Visual Studio has its ARM64 C++ tools),
# the way its build workflow does (github.com/OpenVPN/openvpn-build, .github/workflows/build.yaml and
# windows-msi/build-and-package.ps1): openvpn-build at the release tag with its submodules (openvpn, openvpn-gui and
# the vcpkg they're built with), OpenSSL, LZ4, LZO and pkcs11-helper from vcpkg, openvpn-gui and openvpn with their
# CMake presets (MSVC), the man page with rst2html (docutils), then build.wsf makes the MSI with WiX 3.14.
# As in the official build, the drivers (TAP-Windows6, ovpn-dco), openvpnserv2.exe and Easy-RSA are their signed
# releases, which build.wsf downloads (Windows only loads signed drivers). The MSI and the exes aren't code-signed.
# Needs: Visual Studio 2022 with C++ and its Spectre-mitigated libraries (Microsoft.VisualStudio.Component.VC.Runtimes.x86.x64.Spectre),
#        CMake, Git; Python (for docutils) and WiX 3.14 are downloaded into the tools folder when missing
# Usage: build.cmd [-Version <x.y.z>[-Innn]] [-KeepWork] [-WorkDir <folder>]

$repo = 'OpenVPN/openvpn-build'
$git = Get-Git
# (the release tags are OpenVPN-<x.y.z>-I<nnn>; the newest, or the newest installer build of -Version)
$tags = & $git ls-remote --tags --refs "https://github.com/$repo.git" 'OpenVPN-*' | ForEach-Object { ($_ -split 'refs/tags/')[1] } | Where-Object { $_ -match '^OpenVPN-\d+\.\d+\.\d+-I\d+$' }
if ($LASTEXITCODE -ne 0 -or -not $tags) { throw "Couldn't read the tags of https://github.com/$repo.git" }
if ($Version -match '-I\d+$') { $tags = @($tags | Where-Object { $_ -eq "OpenVPN-$($Version -replace '^v')" }) }
elseif ($Version) { $tags = @($tags | Where-Object { $_ -like "OpenVPN-$($Version -replace '^v')-I*" }) }
$tag = $tags | Sort-Object { $v = [regex]::Match($_, '^OpenVPN-(\d+\.\d+\.\d+)-I(\d+)$'); [version]"$($v.Groups[1].Value).$([int]$v.Groups[2].Value)" } | Select-Object -Last 1
if (-not $tag) { throw "openvpn-build has no release tag for OpenVPN $Version" }
$ver = $tag -replace '^OpenVPN-'
$work = Start-Build -Name 'OpenVPN' -NeedGB 8
$env:GIT_CONFIG_COUNT = '1'; $env:GIT_CONFIG_KEY_0 = 'core.longpaths'; $env:GIT_CONFIG_VALUE_0 = 'true'
$src = Join-Path $work 'src'
Get-GitSource "https://github.com/$repo.git" $tag $src -Submodules
if (-not (Get-Command cmake.exe -ErrorAction SilentlyContinue)) { throw 'This build needs CMake (cmake.org) on the PATH' }

# vcpkg (openvpn-build's submodule), with its downloads and binary cache in the tools folder
$vcpkg = Join-Path $src 'src\vcpkg'
$env:VCPKG_ROOT = $vcpkg; $env:VCPKG_DISABLE_METRICS = '1'; $env:VCPKG_MAX_CONCURRENCY = '4'
$env:VCPKG_OVERLAY_PORTS = Join-Path $src 'windows-msi\vcpkg-ports'
$env:VCPKG_DOWNLOADS = Join-Path $script:toolsDir 'vcpkg-downloads'
$env:VCPKG_DEFAULT_BINARY_CACHE = Join-Path $script:toolsDir 'vcpkg-cache'
New-Item -ItemType Directory -Path $env:VCPKG_DOWNLOADS, $env:VCPKG_DEFAULT_BINARY_CACHE -Force | Out-Null
Invoke-Checked (Join-Path $vcpkg 'bootstrap-vcpkg.bat') -disableMetrics
# (openvpn's triplets build each library in Debug too, which only its Debug presets use: OpenSSL alone takes about an
# hour for each architecture that way, so only Release is built)
Get-ChildItem -LiteralPath (Join-Path $src 'src\openvpn\contrib\vcpkg-triplets') -Filter '*-windows-ovpn.cmake' | ForEach-Object {
    [IO.File]::AppendAllText($_.FullName, "`nset(VCPKG_BUILD_TYPE release)`n")
}

# rst2html for openvpn's man page (docutils, in a venv in the tools folder)
$docVenv = Join-Path $script:toolsDir 'docutils-venv'
if (-not (Test-Path -LiteralPath (Join-Path $docVenv 'Scripts\rst2html.exe'))) {
    Use-Tool python -Version '3.9'
    Say 'Getting docutils (rst2html)...'
    Invoke-Checked python -m venv $docVenv
    Invoke-Checked (Join-Path $docVenv 'Scripts\python.exe') -m pip install --disable-pip-version-check -q docutils
}
Add-ToPath (Join-Path $docVenv 'Scripts')

# WiX 3.14 (the binaries zip the workflow uses), in the tools folder
$wix = Join-Path $script:toolsDir 'wix314'
if (-not (Test-Path -LiteralPath (Join-Path $wix 'bin\candle.exe'))) {
    Say 'Getting WiX 3.14...'
    $zip = Join-Path $script:toolsDir 'wix314-binaries.zip'
    Get-File 'https://github.com/wixtoolset/wix3/releases/download/wix3141rtm/wix314-binaries.zip' $zip
    [IO.Compression.ZipFile]::ExtractToDirectory($zip, (Join-Path $wix 'bin')); Remove-Item -LiteralPath $zip
}
$env:WIX = "$wix\"
# (build.wsf unzips Easy-RSA with unzip.exe, which the build workflow's runner has from Git's tools; Windows' own
# tar.exe unpacks zips too, so Builder.js runs that instead)
$builderJs = Join-Path $src 'windows-msi\script\Builder.js'
$jsText = [IO.File]::ReadAllText($builderJs)
$unzipCall = '"unzip\.exe " \+\s*builder\.unzipFlags\.join\(" "\) \+\s*" -o" \+\s*" -d \\"" \+ _CMD\(this\.outDir\) \+ "\\"" \+\s*" \\"" \+ _CMD\(this\.inNames\[0\]\) \+ "\\""'
if ($jsText -notmatch $unzipCall) { throw "Couldn't find the unzip.exe command in windows-msi\script\Builder.js" }
$jsText = [regex]::Replace($jsText, $unzipCall, '"\"%SystemRoot%\\System32\\tar.exe\" -xf \"" + _CMD(this.inNames[0]) + "\" -C \"" + _CMD(this.outDir) + "\""')
[IO.File]::WriteAllText($builderJs, $jsText)

$env:PATH = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer;$env:PATH"
$env:MSBUILDDISABLENODEREUSE = '1'
$cleanEnv = @{}; Get-ChildItem Env: | ForEach-Object { $cleanEnv[$_.Name] = $_.Value }
function Reset-Env { Get-ChildItem Env: | Where-Object { -not $cleanEnv.ContainsKey($_.Name) } | ForEach-Object { Remove-Item -LiteralPath "Env:$($_.Name)" }; foreach ($k in $cleanEnv.Keys) { Set-Item -LiteralPath "Env:$k" -Value $cleanEnv[$k] } }
function Test-VSComponent([string[]]$Components) {
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    return [bool](& $vswhere -version '[17.0,18.0)' -products * -requires $Components -property installationPath)
}

foreach ($arch in @(
        @{ Ovpn = 'amd64'; Gui = 'x64'; Folder = 'x64' },
        @{ Ovpn = 'x86'; Gui = 'x86'; Folder = 'x86' },
        @{ Ovpn = 'arm64'; Gui = 'arm64'; Folder = 'ARM64'; Needs = @('Microsoft.VisualStudio.Component.VC.Tools.ARM64', 'Microsoft.VisualStudio.Component.VC.Runtimes.ARM64.Spectre') })) {
    if ($arch.Needs -and -not (Test-VSComponent $arch.Needs)) { Say "Skipping $($arch.Folder): Visual Studio 2022 doesn't have $($arch.Needs -join ', ')"; continue }
    Reset-Env
    # (openvpn and openvpn-gui compile with /Qspectre, so they need Visual Studio's Spectre-mitigated libraries;
    # the x64 build environment for every architecture: the presets' Visual Studio generator picks the target, and
    # vcpkg builds its host tools for x64; VCPKG_VISUAL_STUDIO_PATH keeps vcpkg on this Visual Studio 2022)
    $vs = Use-VisualStudio -Arch 'x64' -Version '[17.0,18.0)' -Components (@('Microsoft.VisualStudio.Component.VC.Tools.x86.x64', 'Microsoft.VisualStudio.Component.VC.Runtimes.x86.x64.Spectre', 'Microsoft.VisualStudio.Component.Windows11SDK.26100') + @($arch.Needs | Where-Object { $_ }))
    $env:VCPKG_VISUAL_STUDIO_PATH = $vs

    Say "Building openvpn-gui for $($arch.Folder)..."
    Push-Location -LiteralPath (Join-Path $src 'src\openvpn-gui')
    try {
        Invoke-Checked cmake --preset $arch.Gui
        Invoke-Checked cmake --build --preset "$($arch.Gui)-release" --parallel 4
    }
    finally { Pop-Location }

    Say "Building openvpn for $($arch.Folder)..."
    Push-Location -LiteralPath (Join-Path $src 'src\openvpn')
    try {
        Invoke-Checked cmake --preset "win-$($arch.Ovpn)-release"
        Invoke-Checked cmake --build --preset "win-$($arch.Ovpn)-release" --parallel 4
    }
    finally { Pop-Location }

    Say "Making the MSI for $($arch.Folder)..."
    Push-Location -LiteralPath (Join-Path $src 'windows-msi')
    try { Invoke-Checked cscript.exe //nologo build.wsf "msi-$($arch.Ovpn)" }
    finally { Pop-Location }
    $msi = Get-ChildItem -LiteralPath (Join-Path $src 'windows-msi\image') -Filter "*-$($arch.Ovpn).msi" | Select-Object -First 1
    if (-not $msi) { throw "build.wsf made no *-$($arch.Ovpn).msi" }
    Publish-Build -From $msi.FullName -Arch $arch.Folder -Version $ver -Note "Source: https://github.com/$repo, tag $tag (unsigned MSI; the drivers, openvpnserv2 and Easy-RSA are their official signed releases)"
}
Complete-Build
