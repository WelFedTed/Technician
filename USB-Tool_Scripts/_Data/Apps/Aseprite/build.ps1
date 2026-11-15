# Builds the latest Aseprite release from source and puts it in this app's Portable\x64 folder
# (Aseprite is sold ready-built; its source code can be built for your own use, see its EULA)
#
# What it needs, and how it gets it:
#   Visual Studio 2022 (Community or Build Tools) with "Desktop development with C++" and a Windows SDK:
#     installed with winget when it's missing (several GB, asks for admin; asks you first unless -Yes)
#   Inno Setup 6, to make the installer: installed with winget for this user (no admin) when it's missing
#   CMake and Ninja: used from the PATH, or portable copies are downloaded into the work folder
#   about 5 GB free in the work folder (default %TEMP%\USB-Tool-Aseprite-build, or _Data\Temp on the USB
#   when the PC's drive is too full)
# Anything it can't install (eg. no winget on the PC) it says how to install. A build takes roughly 10-40 minutes.
# It makes the portable build (Portable\x64) and an installer like the official one (Installer\x64).
#
# Usage: build.cmd [-Version <x.y.z>] [-Yes] [-NoInstaller] [-WorkDir <folder>] [-KeepWork]
#   -Version    build this release instead of the latest (eg. -Version 1.3.17.2)
#   -Yes        install Visual Studio's build tools without asking first, when they're missing
#   -NoInstaller  only make the portable build (no installer .exe)
#   -KeepWork   keep the source, Skia and build files afterwards (eg. to rebuild faster)
# The result matches the official portable build (Aseprite.exe, data with the translations, docs, the Explorer
# thumbnailer with its Install/UninstallThumbnailer.bat, aseprite.ini so it runs portable, EULA.txt), except
# for what only the official builds have: crash reporting (aseprite_crashpad_handler.exe), safe_dialogs.exe
# and README.html
param(
    [string]$Version,
    [switch]$Yes,
    [switch]$NoInstaller,
    [string]$WorkDir,
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

# ---- tools that have to be installed: installed with winget when they're missing, or the user is told how
$winget = (Get-Command winget.exe -ErrorAction SilentlyContinue).Source

function Install-WithWinget([string]$id, [string]$what, [string[]]$extra) {
    if (-not $winget) { return $false }
    Say "Installing $what with winget..."
    & $winget install --id $id -e --silent --accept-package-agreements --accept-source-agreements @extra
    return ($LASTEXITCODE -eq 0)
}

# Visual Studio's C++ build tools (cl, link, the Windows SDK)
function Find-VcVars {
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    if (-not (Test-Path -LiteralPath $vswhere)) { return $null }
    $vs = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath | Select-Object -First 1
    if (-not $vs) { return $null }
    $bat = Join-Path $vs 'VC\Auxiliary\Build\vcvars64.bat'
    if (Test-Path -LiteralPath $bat) { return $bat }
    return $null
}
$vcvars = Find-VcVars
if (-not $vcvars) {
    Say "This PC doesn't have Visual Studio's C++ build tools, which Aseprite needs to build."
    $go = $Yes
    if (-not $go -and $winget) {
        $answer = Read-Host 'Install Visual Studio 2022 Build Tools with the C++ tools now? It downloads several GB and asks for admin [Y/n]'
        $go = $answer -notmatch '^\s*n'
    }
    if ($go -and (Install-WithWinget 'Microsoft.VisualStudio.2022.BuildTools' 'Visual Studio 2022 Build Tools (C++)' @('--override', '--wait --passive --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended'))) {
        $vcvars = Find-VcVars
    }
    if (-not $vcvars) {
        Say ''
        Say 'Install Visual Studio 2022 (Community or Build Tools) with "Desktop development with C++" and a Windows SDK,'
        Say 'from https://visualstudio.microsoft.com/downloads/ or with:'
        Say '  winget install Microsoft.VisualStudio.2022.BuildTools --override "--wait --passive --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended"'
        Say 'then run build.cmd again.'
        exit 1
    }
}
Say "Visual Studio: $(Split-Path (Split-Path (Split-Path (Split-Path $vcvars))))"

# Inno Setup, which makes the installer (Aseprite's official installer is made with it too); installed for this
# user only, so it needs no admin. Without it, only the portable build is made.
function Find-Iscc {
    $found = (Get-Command iscc.exe -ErrorAction SilentlyContinue).Source
    if ($found) { return $found }
    foreach ($dir in "$env:LOCALAPPDATA\Programs\Inno Setup 6", "${env:ProgramFiles(x86)}\Inno Setup 6", "$env:ProgramFiles\Inno Setup 6") {
        $exe = Join-Path $dir 'ISCC.exe'
        if (Test-Path -LiteralPath $exe) { return $exe }
    }
    return $null
}
$iscc = Find-Iscc
if (-not $iscc -and $NoInstaller) { }
elseif (-not $iscc) {
    if (Install-WithWinget 'JRSoftware.InnoSetup' 'Inno Setup (for this user)' @('--scope', 'user')) { $iscc = Find-Iscc }
    if (-not $iscc) {
        Say 'WARNING: Inno Setup isn''t installed and couldn''t be installed, so only the portable build will be made.'
        Say '  To make the installer too, install Inno Setup 6 from https://jrsoftware.org/isdl.php (or: winget install JRSoftware.InnoSetup)'
    }
}
if ($iscc) { Say "Inno Setup: $iscc" }

function Get-FreeSpace([string]$path) {
    try { return ([IO.DriveInfo]([IO.Path]::GetPathRoot([IO.Path]::GetFullPath($path)))).AvailableFreeSpace } catch { return 0 }
}
if (-not $WorkDir) {
    # the PC's temp folder builds fastest; when its drive is too full, build on the USB (_Data\Temp) instead
    $WorkDir = Join-Path $env:TEMP 'USB-Tool-Aseprite-build'
    $usbWork = Join-Path (Split-Path -Parent (Split-Path -Parent $appDir)) 'Temp\USB-Tool-Aseprite-build'
    if ((Get-FreeSpace $WorkDir) -lt 5GB -and (Split-Path -Leaf (Split-Path -Parent (Split-Path -Parent $appDir))) -eq '_Data' -and (Get-FreeSpace $usbWork) -ge 5GB) {
        Say ("Only {0:N1} GB is free on this PC's temp drive, so building on the USB instead (slower): $usbWork" -f ((Get-FreeSpace $WorkDir) / 1GB))
        $WorkDir = $usbWork
    }
}
New-Item -ItemType Directory -Path $WorkDir -Force | Out-Null
$free = Get-FreeSpace $WorkDir
if ($free -lt 5GB) { Fail ("Only {0:N1} GB is free where the build happens ({1}); it needs about 5 GB. Free some space, or use -WorkDir to build somewhere else." -f ($free / 1GB), $WorkDir) }
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
    $release = Get-GitHubRelease 'aseprite/aseprite' $(if ($Version) { "v$($Version -replace '^v', '')" })
    $version = ($release.Tag -replace '^v', '')
    $sourceZip = $release.Assets | Where-Object { $_ -match '/Aseprite-v[\d.]+-Source\.zip$' } | Select-Object -First 1
    if (-not $sourceZip) { throw "Couldn't find the source zip in Aseprite's $($release.Tag) release" }
    $installed = Get-ChildItem -LiteralPath (Join-Path $appDir 'Portable') -Filter "v$($version)_*.version" -File -ErrorAction SilentlyContinue
    $installerDone = $NoInstaller -or -not $iscc -or (Test-Path -LiteralPath (Join-Path $appDir "Installer\x64\Aseprite-v$version.exe"))
    if ($installed -and $installerDone -and (Test-Path -LiteralPath (Join-Path $target 'aseprite.exe'))) {
        Say "Aseprite $version is already built here ($($installed.Name)), so there's nothing to do."
        exit 0
    }
    Say "Aseprite: $($release.Tag)"
    $src = Join-Path $WorkDir 'src'
    # with -KeepWork, a source folder left from building this same release is reused (and its build carries on)
    $srcMarker = Join-Path $WorkDir 'src.version'
    if ((Test-Path -LiteralPath $srcMarker) -and (Get-Content -LiteralPath $srcMarker -Raw).Trim() -eq $release.Tag -and (Test-Path -LiteralPath $src)) {
        Say 'Using the source already in the work folder'
    }
    else {
        Say 'Downloading the source...'
        Get-File $sourceZip (Join-Path $WorkDir 'source.zip')
        Say 'Extracting the source...'
        Expand-Zip (Join-Path $WorkDir 'source.zip') $src
        [IO.File]::WriteAllText($srcMarker, $release.Tag)
    }
    # (the zip may or may not have a top folder)
    $top = @(Get-ChildItem -LiteralPath $src)
    if ($top.Count -eq 1 -and $top[0].PSIsContainer) { $src = $top[0].FullName }
    if (-not (Test-Path -LiteralPath (Join-Path $src 'CMakeLists.txt'))) { throw "The source zip doesn't look like Aseprite's source (no CMakeLists.txt)" }

    # the release's source calls itself "<version>-dev" (eg. in Help > About and aseprite --version), but
    # official builds call themselves "<version>-x64" (eg. Aseprite 1.3.17.2-x64), so this does too
    $verCmake = Join-Path $src 'src\ver\CMakeLists.txt'
    if (Test-Path -LiteralPath $verCmake) {
        $verText = [IO.File]::ReadAllText($verCmake)
        $fixed = [regex]::Replace($verText, 'set\(VERSION "([^"]+?)-dev"\)', 'set(VERSION "$1-x64")')
        if ($fixed -ne $verText) { [IO.File]::WriteAllText($verCmake, $fixed) }
    }

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
        # /FS: compile jobs running at once share the debug-symbols file safely (without it, builds can
        # fail at random with "error C2471: cannot update program database")
        'set "CL=/FS"'
        "set `"PATH=$(Split-Path $cmake);$(Split-Path $ninja);%PATH%`""
        "cd /d `"$build`""
        "cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo -DLAF_BACKEND=skia -DENABLE_DESKTOP_INTEGRATION=ON -DSKIA_DIR=`"$skia`" -DSKIA_LIBRARY_DIR=`"$skiaLib`" -DSKIA_LIBRARY=`"$skiaLib\skia.lib`" -G Ninja .. || exit /b 1"
        # (aseprite-thumbnailer.dll shows .aseprite thumbnails in File Explorer, as in the official builds)
        # (if a compile step still fails, eg. a file briefly locked by antivirus, try again: ninja carries on
        # from where it stopped)
        'ninja aseprite aseprite-thumbnailer || ninja aseprite aseprite-thumbnailer || exit /b 1'
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
    # what else the official portable build has: the thumbnailer (and the .bat files that register it with File
    # Explorer), aseprite.ini so Aseprite keeps its settings here (portable), and the EULA
    $thumb = Get-ChildItem -LiteralPath $build -Recurse -Filter 'aseprite-thumbnailer.dll' -File | Select-Object -First 1
    if ($thumb) {
        Copy-Item -LiteralPath $thumb.FullName -Destination $target -Force
        [IO.File]::WriteAllText((Join-Path $target 'InstallThumbnailer.bat'), "@echo off`r`necho Installing aseprite-thumbnailer.dll...`r`nregsvr32.exe aseprite-thumbnailer.dll`r`n")
        [IO.File]::WriteAllText((Join-Path $target 'UninstallThumbnailer.bat'), "@echo off`r`necho Uninstalling aseprite-thumbnailer.dll...`r`nregsvr32.exe -u aseprite-thumbnailer.dll`r`n")
    }
    else { Say 'WARNING: the thumbnailer (aseprite-thumbnailer.dll) wasn''t built, so it was left out' }
    if (-not (Test-Path -LiteralPath (Join-Path $target 'aseprite.ini'))) {
        [IO.File]::WriteAllText((Join-Path $target 'aseprite.ini'), "# This file is here so Aseprite behaves as a portable program`n")
    }
    if (Test-Path -LiteralPath (Join-Path $src 'EULA.txt')) { Copy-Item -LiteralPath (Join-Path $src 'EULA.txt') -Destination $target -Force }
    # the docs folder (file format specs, licenses)
    $docs = @(Get-ChildItem -LiteralPath (Join-Path $src 'docs') -Filter '*.md' -File -ErrorAction SilentlyContinue)
    if ($docs) {
        New-Item -ItemType Directory -Path (Join-Path $target 'docs') -Force | Out-Null
        $docs | Copy-Item -Destination (Join-Path $target 'docs') -Force
    }

    # translations: the source only has English; official builds add the aseprite/strings repo as it was when
    # the release came out. Its languages are picked by hand for each release, so this takes the ones at
    # least 70% translated (for 1.3.17.2: all 26 official ones, plus Irish and Cornish, which are complete)
    Say 'Adding the translations...'
    try {
        $stringsRef = 'main'
        try {
            $published = (Get-Text "https://api.github.com/repos/aseprite/aseprite/releases/tags/$($release.Tag)" | ConvertFrom-Json).published_at
            if ($published -is [datetime]) { $published = $published.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ') }
            $commit = @(Get-Text "https://api.github.com/repos/aseprite/strings/commits?until=$published&per_page=1" | ConvertFrom-Json)[0].sha
            if ($commit -match '^[0-9a-f]{40}$') { $stringsRef = $commit }
        }
        catch { Say "  (GitHub's API isn't answering, eg. its hourly limit ran out, so using the latest translations)" }
        $stringsZip = Join-Path $WorkDir 'strings.zip'
        Get-File "https://codeload.github.com/aseprite/strings/zip/$stringsRef" $stringsZip
        $stringsSrc = Join-Path $WorkDir 'strings'
        Expand-Zip $stringsZip $stringsSrc
        $stringsTop = @(Get-ChildItem -LiteralPath $stringsSrc -Directory)
        if ($stringsTop.Count -eq 1) { $stringsSrc = $stringsTop[0].FullName }
        $stringsDir = Join-Path $target 'data\strings'
        $keyPattern = '(?m)^[A-Za-z0-9_]+ *= *\S'
        $englishKeys = [regex]::Matches([IO.File]::ReadAllText((Join-Path $stringsDir 'en.ini')), $keyPattern).Count
        $added = @()
        foreach ($file in Get-ChildItem -LiteralPath $stringsSrc -File) {
            if ($file.Extension -eq '.ini') {
                # (en.ini comes from the source, which is the release's own)
                if ($file.Name -eq 'en.ini') { continue }
                $done = [regex]::Matches([IO.File]::ReadAllText($file.FullName), $keyPattern).Count / [Math]::Max(1, $englishKeys)
                if ($done -lt 0.7) { continue }
                $added += $file.BaseName
            }
            elseif ($file.Name -notin @('LICENSE.txt', 'README.md')) { continue }
            # (with Windows line endings, as in the official builds)
            $bytes = [IO.File]::ReadAllBytes($file.FullName)
            $hasBom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
            $text = [IO.File]::ReadAllText($file.FullName, [Text.Encoding]::UTF8) -replace "`r?`n", "`r`n"
            [IO.File]::WriteAllText((Join-Path $stringsDir $file.Name), $text, (New-Object Text.UTF8Encoding $hasBom))
        }
        Say "  $($added.Count) languages ($($added -join ', ')), from aseprite/strings $(if ($stringsRef -eq 'main') { 'main' } else { $stringsRef.Substring(0, 7) })"
    }
    catch { Say "WARNING: couldn't add the translations ($($_.Exception.Message)), so this build is English only" }

    # a version file, like the other apps' (v<version>_<date>.version)
    $portable = Join-Path $appDir 'Portable'
    Get-ChildItem -LiteralPath $portable -Filter '*.version' -File | Remove-Item -Force
    $stamp = Get-Date
    [IO.File]::WriteAllText((Join-Path $portable ('v{0}_{1}.version' -f $version, $stamp.ToString('yyyy-MM-dd'))), "link=$sourceZip`r`nskia=$skiaZip`r`nbuilt=$($stamp.ToString('yyyy-MM-dd'))")
    Say "Portable build: $target"

    # ---- the installer (Inno Setup, like the official one), from the portable build
    if ($iscc -and -not $NoInstaller) {
        Say ''
        Say 'Making the installer...'
        $installerDir = Join-Path $appDir 'Installer\x64'
        New-Item -ItemType Directory -Path $installerDir -Force | Out-Null
        Get-ChildItem -LiteralPath $installerDir -Filter 'Aseprite-v*.exe' -File | Remove-Item -Force
        $icons = Join-Path $target 'data\icons'
        # Inno Setup's version info needs four numbers (eg. 1.3.17.2)
        $numbers = @([regex]::Matches($version, '\d+') | ForEach-Object { $_.Value })
        while ($numbers.Count -lt 4) { $numbers += '0' }
        $hasThumbnailer = Test-Path -LiteralPath (Join-Path $target 'aseprite-thumbnailer.dll')
        $iss = @"
; Aseprite $version, built from source by the USB tool's build.cmd
[Setup]
; (its own AppId, so it doesn't replace or uninstall an official Aseprite install)
AppId={{6D1F3A52-8C4B-4E7A-9B0D-2F5E7C9A1B34}
AppName=Aseprite
AppVersion=$version
AppVerName=Aseprite $version
AppPublisher=Igara Studio S.A.
AppPublisherURL=https://www.aseprite.org/
AppSupportURL=https://www.aseprite.org/support/
VersionInfoVersion=$($numbers[0..3] -join '.')
VersionInfoDescription=Aseprite Setup
VersionInfoProductName=Aseprite
DefaultDirName={autopf}\Aseprite
DefaultGroupName=Aseprite
DisableProgramGroupPage=yes
PrivilegesRequired=admin
PrivilegesRequiredOverridesAllowed=dialog
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
LicenseFile=$target\EULA.txt
SetupIconFile=$(Join-Path $src 'data\icons\ase.ico')
UninstallDisplayIcon={app}\Aseprite.exe
OutputDir=$installerDir
OutputBaseFilename=Aseprite-v$version
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ChangesAssociations=yes

[Tasks]
Name: desktopicon; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
; (one per file type, as in the official installer)
Name: aseassoc; Description: "Open .ase files with Aseprite"; GroupDescription: "Files:"
Name: asepriteassoc; Description: "Open .aseprite files with Aseprite"; GroupDescription: "Files:"
Name: asepriteextensionassoc; Description: "Install .aseprite-extension files with Aseprite"; GroupDescription: "Files:"
$(if ($hasThumbnailer) { 'Name: asethumb; Description: "Show .ase and .aseprite thumbnails in File Explorer"; GroupDescription: "Files:"; Check: IsAdminInstallMode' })

[Files]
; (not aseprite.ini: that makes Aseprite portable, keeping its settings in its own folder)
Source: "$target\*"; DestDir: "{app}"; Excludes: "aseprite.ini,InstallThumbnailer.bat,UninstallThumbnailer.bat,aseprite-thumbnailer.dll"; Flags: ignoreversion recursesubdirs createallsubdirs
$(if ($hasThumbnailer) { "Source: `"$target\aseprite-thumbnailer.dll`"; DestDir: `"{app}`"; Flags: ignoreversion regserver; Tasks: asethumb" })

[Icons]
; (in an Aseprite folder in the Start menu, as in the official installer)
Name: "{group}\Aseprite"; Filename: "{app}\Aseprite.exe"
Name: "{autodesktop}\Aseprite"; Filename: "{app}\Aseprite.exe"; Tasks: desktopicon

[Registry]
; (its own file type names, Aseprite.Sprite / Aseprite.Extension, so it doesn't change an official install's
; AsepriteFile / AsepriteExtension when both are installed)
Root: HKA; Subkey: "Software\Classes\.ase"; ValueType: string; ValueName: ""; ValueData: "Aseprite.Sprite"; Flags: uninsdeletevalue uninsdeletekeyifempty; Tasks: aseassoc
Root: HKA; Subkey: "Software\Classes\.aseprite"; ValueType: string; ValueName: ""; ValueData: "Aseprite.Sprite"; Flags: uninsdeletevalue uninsdeletekeyifempty; Tasks: asepriteassoc
Root: HKA; Subkey: "Software\Classes\Aseprite.Sprite"; ValueType: string; ValueName: ""; ValueData: "Aseprite Sprite"; Flags: uninsdeletekey; Tasks: aseassoc asepriteassoc
Root: HKA; Subkey: "Software\Classes\Aseprite.Sprite\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "$(if (Test-Path -LiteralPath (Join-Path $icons 'doc.ico')) { '{app}\data\icons\doc.ico' } else { '{app}\Aseprite.exe,0' })"; Tasks: aseassoc asepriteassoc
Root: HKA; Subkey: "Software\Classes\Aseprite.Sprite\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\Aseprite.exe"" ""%1"""; Tasks: aseassoc asepriteassoc
Root: HKA; Subkey: "Software\Classes\.aseprite-extension"; ValueType: string; ValueName: ""; ValueData: "Aseprite.Extension"; Flags: uninsdeletevalue uninsdeletekeyifempty; Tasks: asepriteextensionassoc
Root: HKA; Subkey: "Software\Classes\Aseprite.Extension"; ValueType: string; ValueName: ""; ValueData: "Aseprite Extension"; Flags: uninsdeletekey; Tasks: asepriteextensionassoc
Root: HKA; Subkey: "Software\Classes\Aseprite.Extension\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "$(if (Test-Path -LiteralPath (Join-Path $icons 'ext.ico')) { '{app}\data\icons\ext.ico' } else { '{app}\Aseprite.exe,0' })"; Tasks: asepriteextensionassoc
Root: HKA; Subkey: "Software\Classes\Aseprite.Extension\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\Aseprite.exe"" ""%1"""; Tasks: asepriteextensionassoc

[Run]
Filename: "{app}\Aseprite.exe"; Description: "{cm:LaunchProgram,Aseprite}"; Flags: nowait postinstall skipifsilent
"@
        $issFile = Join-Path $WorkDir 'aseprite.iss'
        # (Inno Setup reads scripts as UTF-8 with a byte order mark)
        [IO.File]::WriteAllText($issFile, ($iss -replace "`r?`n", "`r`n"), (New-Object Text.UTF8Encoding $true))
        & $iscc /Q $issFile
        if ($LASTEXITCODE -ne 0) { throw "Inno Setup couldn't make the installer (exit code $LASTEXITCODE)" }
        $setup = Join-Path $installerDir "Aseprite-v$version.exe"
        if (-not (Test-Path -LiteralPath $setup)) { throw "Inno Setup finished but there's no $setup" }
        $installerVersionDir = Join-Path $appDir 'Installer'
        Get-ChildItem -LiteralPath $installerVersionDir -Filter '*.version' -File | Remove-Item -Force
        [IO.File]::WriteAllText((Join-Path $installerVersionDir ('v{0}_{1}.version' -f $version, $stamp.ToString('yyyy-MM-dd'))), "link=$sourceZip`r`nskia=$skiaZip`r`nbuilt=$($stamp.ToString('yyyy-MM-dd'))")
        Say "Installer: $setup"
    }
    Say ''
    Say "Done: Aseprite $version"
}
catch { Fail $_.Exception.Message }
finally {
    if (-not $KeepWork) {
        # (the downloaded CMake / Ninja are kept for next time; the rest is several GB)
        foreach ($item in 'src', 'skia', 'source.zip', 'skia.zip', 'build-steps.cmd', 'src.version', 'strings', 'strings.zip', 'aseprite.iss') {
            $path = Join-Path $WorkDir $item
            if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Recurse -Force -ErrorAction SilentlyContinue }
        }
    }
}
