# Builds the latest Aseprite release from source and puts it in this app's Portable\x64 folder
# (Aseprite is sold ready-built; its source code can be built for your own use, see its EULA)
#
# Needs, on the PC it runs on:
#   Visual Studio 2022 (Community or Build Tools) with "Desktop development with C++" and a Windows 10/11 SDK
#   about 5 GB free in the work folder (default %TEMP%\USB-Tool-Aseprite-build)
# CMake and Ninja are used from the PATH if they're there, otherwise portable copies are downloaded into the
# work folder. Nothing is installed. A build takes roughly 10-40 minutes.
#
# Usage: build.cmd [-WorkDir <folder>] [-KeepWork]
#   -KeepWork   keep the source, Skia and build files afterwards (eg. to rebuild faster)
param(
    [string]$WorkDir = (Join-Path $env:TEMP 'USB-Tool-Aseprite-build'),
    [switch]$KeepWork
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36'
$curl = Join-Path $env:SystemRoot 'System32\curl.exe'
$appDir = $PSScriptRoot
$target = Join-Path $appDir 'Portable\x64'
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Say([string]$message) { Write-Host $message }
function Fail([string]$message) { Say ''; Say "FAILED: $message"; exit 1 }

function Get-Text([string]$address) {
    $text = & $curl -sSL --fail --retry 2 --connect-timeout 20 -A $userAgent $address | Out-String
    if ($LASTEXITCODE -ne 0) { throw "Couldn't load $address (curl exit code $LASTEXITCODE)" }
    return $text
}

function Get-File([string]$address, [string]$outFile) {
    & $curl -L --fail --retry 2 --connect-timeout 20 --progress-bar -A $userAgent -o $outFile $address
    if ($LASTEXITCODE -ne 0) { throw "Couldn't download $address (curl exit code $LASTEXITCODE)" }
}

# a GitHub release's tag and files, from the API or, when its hourly limit has run out, the release pages
function Get-GitHubRelease([string]$repo, [string]$tag) {
    if (-not $tag) {
        try { $tag = (Get-Text "https://api.github.com/repos/$repo/releases/latest" | ConvertFrom-Json).tag_name }
        catch {
            $final = & $curl -sSIL --fail -A $userAgent -o NUL -w '%{url_effective}' "https://github.com/$repo/releases/latest"
            if ("$final" -notmatch '/releases/tag/(.+)$') { throw "Couldn't find the latest release of $repo" }
            $tag = [Uri]::UnescapeDataString($Matches[1])
        }
    }
    $html = Get-Text "https://github.com/$repo/releases/expanded_assets/$tag"
    $assets = @([regex]::Matches($html, 'href="(/[^"/]+/[^"/]+/releases/download/[^"]+)"') | ForEach-Object { 'https://github.com' + $_.Groups[1].Value } | Select-Object -Unique)
    return [pscustomobject]@{ Tag = $tag; Assets = $assets }
}

function Expand-Zip([string]$zip, [string]$to) {
    if (Test-Path -LiteralPath $to) { Remove-Item -LiteralPath $to -Recurse -Force }
    [IO.Compression.ZipFile]::ExtractToDirectory($zip, $to)
}

Say 'Building Aseprite from source'
Say ('-' * 100)

# ---- Visual Studio's C++ tools (the one thing that has to be installed)
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
$vs = if (Test-Path -LiteralPath $vswhere) { & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath | Select-Object -First 1 }
$vcvars = if ($vs) { Join-Path $vs 'VC\Auxiliary\Build\vcvars64.bat' }
if (-not $vcvars -or -not (Test-Path -LiteralPath $vcvars)) {
    Say "This PC doesn't have Visual Studio's C++ build tools, which Aseprite needs to build."
    Say 'Install Visual Studio 2022 Community or Build Tools with "Desktop development with C++" and a Windows SDK,'
    Say 'eg. from https://visualstudio.microsoft.com/downloads/ or with:'
    Say '  winget install Microsoft.VisualStudio.2022.BuildTools --override "--add Microsoft.VisualStudio.Workload.VCTools --includeRecommended --passive"'
    Say 'then run build.cmd again.'
    exit 1
}
Say "Visual Studio: $vs"

New-Item -ItemType Directory -Path $WorkDir -Force | Out-Null
$free = (Get-PSDrive -Name ((Resolve-Path -LiteralPath $WorkDir).Path.Substring(0, 1))).Free
if ($free -lt 5GB) { Fail ("Only {0:N1} GB is free where the build happens ({1}); it needs about 5 GB. Use -WorkDir to build somewhere else." -f ($free / 1GB), $WorkDir) }
$tools = Join-Path $WorkDir 'tools'
New-Item -ItemType Directory -Path $tools -Force | Out-Null

try {
    # ---- CMake and Ninja: from the PATH, or portable copies in the work folder
    $cmake = (Get-Command cmake.exe -ErrorAction SilentlyContinue).Source
    if (-not $cmake) {
        $cmake = Get-ChildItem -LiteralPath $tools -Recurse -Filter cmake.exe -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
        if (-not $cmake) {
            Say 'Downloading CMake (portable, into the work folder)...'
            $release = Get-GitHubRelease 'Kitware/CMake'
            $zip = $release.Assets | Where-Object { $_ -match '/cmake-[\d.]+-windows-x86_64\.zip$' } | Select-Object -First 1
            if (-not $zip) { throw "Couldn't find CMake's Windows zip in its $($release.Tag) release" }
            Get-File $zip (Join-Path $tools 'cmake.zip')
            Expand-Zip (Join-Path $tools 'cmake.zip') (Join-Path $tools 'cmake')
            $cmake = Get-ChildItem -LiteralPath (Join-Path $tools 'cmake') -Recurse -Filter cmake.exe | Select-Object -First 1 -ExpandProperty FullName
        }
    }
    $ninja = (Get-Command ninja.exe -ErrorAction SilentlyContinue).Source
    if (-not $ninja) {
        $ninja = Join-Path $tools 'ninja.exe'
        if (-not (Test-Path -LiteralPath $ninja)) {
            Say 'Downloading Ninja (portable, into the work folder)...'
            $release = Get-GitHubRelease 'ninja-build/ninja'
            $zip = $release.Assets | Where-Object { $_ -match '/ninja-win\.zip$' } | Select-Object -First 1
            if (-not $zip) { throw "Couldn't find Ninja's Windows zip in its $($release.Tag) release" }
            Get-File $zip (Join-Path $tools 'ninja.zip')
            Expand-Zip (Join-Path $tools 'ninja.zip') (Join-Path $tools 'ninja')
            Move-Item -LiteralPath (Join-Path $tools 'ninja\ninja.exe') -Destination $ninja -Force
        }
    }
    Say "CMake: $cmake"
    Say "Ninja: $ninja"

    # ---- Aseprite's source (the release's -Source.zip includes everything it needs, unlike a git clone)
    $release = Get-GitHubRelease 'aseprite/aseprite'
    $version = ($release.Tag -replace '^v', '')
    $sourceZip = $release.Assets | Where-Object { $_ -match '/Aseprite-v[\d.]+-Source\.zip$' } | Select-Object -First 1
    if (-not $sourceZip) { throw "Couldn't find the source zip in Aseprite's $($release.Tag) release" }
    $installed = Get-ChildItem -LiteralPath (Join-Path $appDir 'Portable') -Filter "v$($version)_*.version" -File -ErrorAction SilentlyContinue
    if ($installed -and (Test-Path -LiteralPath (Join-Path $target 'aseprite.exe'))) {
        Say "Aseprite $version is already built here ($($installed.Name)), so there's nothing to do."
        exit 0
    }
    Say "Aseprite: $($release.Tag)"
    $src = Join-Path $WorkDir 'src'
    Say 'Downloading the source...'
    Get-File $sourceZip (Join-Path $WorkDir 'source.zip')
    Say 'Extracting the source...'
    Expand-Zip (Join-Path $WorkDir 'source.zip') $src
    # (the zip may or may not have a top folder)
    $top = @(Get-ChildItem -LiteralPath $src)
    if ($top.Count -eq 1 -and $top[0].PSIsContainer) { $src = $top[0].FullName }
    if (-not (Test-Path -LiteralPath (Join-Path $src 'CMakeLists.txt'))) { throw "The source zip doesn't look like Aseprite's source (no CMakeLists.txt)" }

    # ---- Skia: the prebuilt branch this release's INSTALL.md asks for (eg. aseprite-m124)
    $install = Get-Content -LiteralPath (Join-Path $src 'INSTALL.md') -Raw
    $m = [regex]::Match($install, 'aseprite-m(\d+)')
    if (-not $m.Success) { throw "Couldn't find which Skia version Aseprite needs in its INSTALL.md" }
    $skiaBranch = $m.Groups[1].Value
    $skiaTag = [regex]::Matches((Get-Text 'https://github.com/aseprite/skia/releases'), "releases/tag/(m$skiaBranch-[0-9a-f]+)") | ForEach-Object { $_.Groups[1].Value } | Select-Object -First 1
    if (-not $skiaTag) { throw "Couldn't find a Skia m$skiaBranch release" }
    $skiaZip = (Get-GitHubRelease 'aseprite/skia' $skiaTag).Assets | Where-Object { $_ -match '/Skia-Windows-Release-x64\.zip$' } | Select-Object -First 1
    if (-not $skiaZip) { throw "Couldn't find Skia-Windows-Release-x64.zip in Skia's $skiaTag release" }
    Say "Skia: $skiaTag"
    $skia = Join-Path $WorkDir 'skia'
    if (-not (Test-Path -LiteralPath (Join-Path $skia 'out\Release-x64\skia.lib'))) {
        Say 'Downloading Skia...'
        Get-File $skiaZip (Join-Path $WorkDir 'skia.zip')
        Expand-Zip (Join-Path $WorkDir 'skia.zip') $skia
    }

    # ---- build, inside Visual Studio's 64-bit build environment
    $build = Join-Path $src 'build'
    New-Item -ItemType Directory -Path $build -Force | Out-Null
    $skiaLib = Join-Path $skia 'out\Release-x64'
    $script = Join-Path $WorkDir 'build-steps.cmd'
    $steps = @(
        '@echo off'
        "call `"$vcvars`" >nul || exit /b 1"
        "set `"PATH=$(Split-Path $cmake);$(Split-Path $ninja);%PATH%`""
        "cd /d `"$build`""
        "cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo -DLAF_BACKEND=skia -DSKIA_DIR=`"$skia`" -DSKIA_LIBRARY_DIR=`"$skiaLib`" -DSKIA_LIBRARY=`"$skiaLib\skia.lib`" -G Ninja .. || exit /b 1"
        'ninja aseprite || exit /b 1'
    )
    [IO.File]::WriteAllText($script, (($steps -join "`r`n") + "`r`n"), [Text.Encoding]::ASCII)
    Say ''
    Say 'Building (this takes a while)...'
    & cmd.exe /d /c "`"$script`""
    if ($LASTEXITCODE -ne 0) { throw "The build failed (exit code $LASTEXITCODE); scroll up for the error" }
    $bin = Join-Path $build 'bin'
    if (-not (Test-Path -LiteralPath (Join-Path $bin 'aseprite.exe'))) { throw "The build finished but there's no aseprite.exe in $bin" }

    # ---- into Portable\x64 (keeping aseprite.ini, its settings when run portable)
    Say ''
    Say "Copying the build to $target..."
    New-Item -ItemType Directory -Path $target -Force | Out-Null
    Get-ChildItem -LiteralPath $target -Force | Where-Object { $_.Name -ne 'aseprite.ini' } | Remove-Item -Recurse -Force
    # (gen.exe is a code generator the build uses, not part of Aseprite)
    Get-ChildItem -LiteralPath $bin -Force | Where-Object { $_.Extension -notin @('.pdb', '.ilk', '.lib', '.exp') -and $_.Name -ne 'gen.exe' } | Copy-Item -Destination $target -Recurse -Force
    # a version file, like the other apps' (v<version>_<date>.version)
    $portable = Join-Path $appDir 'Portable'
    Get-ChildItem -LiteralPath $portable -Filter '*.version' -File | Remove-Item -Force
    $stamp = Get-Date
    [IO.File]::WriteAllText((Join-Path $portable ('v{0}_{1}.version' -f $version, $stamp.ToString('yyyy-MM-dd'))), "link=$sourceZip`r`nskia=$skiaZip`r`nbuilt=$($stamp.ToString('yyyy-MM-dd'))")
    Say "Done: Aseprite $version is in $target"
}
catch { Fail $_.Exception.Message }
finally {
    if (-not $KeepWork) {
        # (the downloaded CMake / Ninja are kept for next time; the rest is several GB)
        foreach ($item in 'src', 'skia', 'source.zip', 'skia.zip', 'build-steps.cmd') {
            $path = Join-Path $WorkDir $item
            if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Recurse -Force -ErrorAction SilentlyContinue }
        }
    }
}
