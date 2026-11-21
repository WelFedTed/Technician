# _Build-App.ps1 - shared helpers for the apps' build.ps1 scripts (dot-sourced: . "$PSScriptRoot\..\_Build-App.ps1")
# --------------------------------------------------
# A build.ps1 builds its app from source into the app's Built folder (eg. _Data\Apps\WinDirStat\Built\x64), next
# to the official download that update.cmd keeps in Installer / Portable. update.cmd never touches Built, and
# run.cmd / install.cmd keep starting the official build.
#
# Each build.ps1 starts with: param([string]$Version, [string]$WorkDir, [switch]$KeepWork, [switch]$Yes)
#                            . "$PSScriptRoot\..\_Build-App.ps1"   (..\..\ for an app in a group folder)
#                            trap { Stop-Build $_ }
# and takes these options (passed on from build.cmd):
#   -Version <x.y.z>   build this release instead of the latest
#   -WorkDir <folder>  where the source and the build go (default %TEMP%\USB-Tool-Build\<app>, or _Data\Temp on the
#                      USB when the PC's drive is too full)
#   -KeepWork          keep the work folder afterwards (eg. to rebuild faster)
#   -Yes               install missing Visual Studio parts without asking first
# and uses these:
#   Start-Build -Name <app> [-NeedGB <n>]        work folder, free space check; sets $Work
#   Get-LatestGitHubTag <owner/repo> [-Pre] [-Match <regex>]
#   Get-GitSource <url> <tag or branch> <folder> [-Submodules]   a shallow clone of that tag
#   Get-File <url> <file>, Get-Text <url>, Expand-Archive7 <archive> <folder>
#   Use-VisualStudio [-Arch x64|x86|arm64] [-Version '[17.0,18.0)'] [-Components ...]   loads its build environment
#   Use-Msys2 -Packages ... ; Invoke-Msys2 -Env mingw64|mingw32|ucrt64|msys -Command '...' [-Dir <folder>]
#   Use-Tool go|node|dotnet|ninja|jdk|python|rust [-Version ...]   adds it to the PATH, getting a portable copy
#                                                  into the shared tools folder when this PC doesn't have it
#   Use-NodeVersion <24 | 24.22.1>               the Node.js version a project pins (Use-Tool node takes any newer one)
#   Invoke-Checked <exe> <args...>               runs it and fails the build on a non-zero exit code
#   Add-NuGetOrg <folder>                        a NuGet.Config there with nuget.org (some PCs' own config has no sources)
#   Publish-Build -From <folder> -Arch x64 -Version <v> [-Files <names>] [-Note <text>]   copies the result into Built\<arch>
#   Complete-Build                               removes the work folder (unless -KeepWork) and says where the build is
# Portable toolchains are kept between builds in %TEMP%\USB-Tool-Build\_tools, so the next build is faster.
# Nothing is installed on the PC, except Visual Studio parts (which it asks about first, unless -Yes).
#
# Windows PowerShell gotchas when passing options to programs (found while writing the build scripts):
#   - quote an argument with a comma ('-tags a,b'), a dot after a colon or equals ('-modfile=go120.mod') or a
#     double quote; an unquoted comma makes an array, and embedded " are dropped
#   - -x:y is split in two (-m:4 arrives as -m: and 4), and a bare -- disappears: use /m:4, /p:Name=Value and '--'
#   - run npm / npx / yarn / pnpm as npm.cmd etc. (their .ps1 shims lose the arguments)
#   - in Invoke-Msys2 -Command, use single quotes inside the bash command (it's run from a file, so " works too)
#   - with msbuild /m:4, also pass /p:CL_MPCount=1 for projects that compile with /MP (or each runs a cl per core)
#   - inside a function, send a tool's output to Out-Host, or it ends up in the function's return value
#   - Get-ChildItem -LiteralPath X -Recurse -Include *.pdb ignores -Include: filter on .Extension instead
#   - many tools fail on paths over 260 characters, so keep -WorkDir short (the default under %TEMP% is)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$script:curl = Join-Path $env:SystemRoot 'System32\curl.exe'
$script:buildRoot = Join-Path $env:TEMP 'USB-Tool-Build'
$script:toolsDir = Join-Path $script:buildRoot '_tools'
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Say([string]$message) { Write-Host $message }
function Fail([string]$message) { Say ''; Say "FAILED: $message"; exit 1 }

# a build.ps1's "trap { Stop-Build $_ }": anything that goes wrong ends the build with what it was, keeping the
# work folder to look at (a trap only covers the script it's in, so each build.ps1 has its own)
function Stop-Build($errorRecord) {
    Say ''
    Say "FAILED: $($errorRecord.Exception.Message)"
    if ($script:Work -and (Test-Path -LiteralPath $script:Work)) { Say "(the source and build files are in $($script:Work); build.cmd removes them next time)" }
    exit 1
}

function Get-Text([string]$address) {
    $text = & $script:curl -sSL --fail --retry 2 --connect-timeout 20 $address | Out-String
    if ($LASTEXITCODE -ne 0) { throw "Couldn't load $address (curl exit code $LASTEXITCODE)" }
    return $text
}

function Get-File([string]$address, [string]$outFile) {
    New-Item -ItemType Directory -Path (Split-Path -Parent $outFile) -Force | Out-Null
    & $script:curl -L --fail --retry 2 --connect-timeout 20 --progress-bar -o $outFile $address
    if ($LASTEXITCODE -ne 0) { throw "Couldn't download $address (curl exit code $LASTEXITCODE)" }
}

function Get-FreeSpace([string]$path) {
    try { return ([IO.DriveInfo]([IO.Path]::GetPathRoot([IO.Path]::GetFullPath($path)))).AvailableFreeSpace } catch { return 0 }
}

# runs a program, failing the build if it doesn't exit with 0
# (no named parameters, so none of a program's own options, eg. -p or -o, can be taken for one)
function Invoke-Checked {
    $program = $args[0]
    $rest = @($args | Select-Object -Skip 1)
    & $program @rest
    if ($LASTEXITCODE -ne 0) { throw "$(Split-Path -Leaf $program) $($rest -join ' ') failed (exit code $LASTEXITCODE)" }
}

# a NuGet.Config with nuget.org in this folder (restores below it use it, even when the PC's own config has no sources)
function Add-NuGetOrg([string]$dir) {
    [IO.File]::WriteAllText((Join-Path $dir 'NuGet.Config'), "<?xml version=`"1.0`" encoding=`"utf-8`"?>`r`n<configuration>`r`n  <packageSources>`r`n    <add key=`"nuget.org`" value=`"https://api.nuget.org/v3/index.json`" protocolVersion=`"3`" />`r`n  </packageSources>`r`n</configuration>`r`n")
}

# the work folder: -WorkDir, %TEMP%\USB-Tool-Build\<app>, or _Data\Temp on the USB when the PC's drive is too full
function Start-Build([string]$Name, [int]$NeedGB = 2) {
    $script:appName = $Name
    $script:appDir = Split-Path -Parent $MyInvocation.PSCommandPath
    if (-not $script:appDir) { $script:appDir = $PSScriptRoot }
    $dir = $WorkDir
    if (-not $dir) {
        $dir = Join-Path $script:buildRoot ($Name -replace '[\\/:*?"<>|]', '_')
        if ((Get-FreeSpace $env:TEMP) -lt $NeedGB * 1GB) {
            # (_Data\Temp: up from the app's folder to _Data\Apps, for apps in a group folder too)
            $apps = $script:appDir; while ($apps -and (Split-Path -Leaf $apps) -ne 'Apps') { $apps = Split-Path -Parent $apps }
            $usbTemp = Join-Path (Split-Path -Parent $apps) 'Temp'
            if ((Get-FreeSpace $usbTemp) -ge $NeedGB * 1GB) {
                $dir = Join-Path $usbTemp "Build-$($Name -replace '[\\/:*?"<>|]', '_')"
                Say "Not enough space in $env:TEMP, so building in $dir"
            }
            else { Fail "Building $Name needs about $NeedGB GB free (in $env:TEMP or on the USB); use -WorkDir to build somewhere else" }
        }
    }
    if (Test-Path -LiteralPath $dir) { Remove-Item -LiteralPath $dir -Recurse -Force }
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    if ($dir.Length -gt 100) { Say "Note: $dir is a long path; some build tools fail on paths over 260 characters, so a shorter -WorkDir may be needed" }
    # (MSBuild's worker processes would otherwise stay running and keep files in the work folder locked)
    $env:MSBUILDDISABLENODEREUSE = '1'
    # (projects' batch files run each other from the current folder by bare name, which cmd skips when this is set,
    # as some terminals do)
    Remove-Item -LiteralPath Env:NoDefaultCurrentDirectoryInExePath -ErrorAction SilentlyContinue
    $script:Work = $dir
    $script:buildStarted = Get-Date
    Say "Building $Name in $dir"
    Say ''
    return $dir
}

# the newest release's tag (from the API, or the releases page when its hourly limit has run out)
function Get-LatestGitHubTag([string]$repo, [switch]$Pre, [string]$Match) {
    try {
        if ($Pre -or $Match) {
            $all = @(Get-Text "https://api.github.com/repos/$repo/releases?per_page=50" | ConvertFrom-Json) | ForEach-Object { $_ }
            $pick = $all | Where-Object { -not $_.draft -and ($Pre -or -not $_.prerelease) -and (-not $Match -or $_.tag_name -match $Match) } | Select-Object -First 1
            if ($pick) { return $pick.tag_name }
        }
        else { return (Get-Text "https://api.github.com/repos/$repo/releases/latest" | ConvertFrom-Json).tag_name }
    }
    catch {
        $final = & $script:curl -sSIL --fail -o NUL -w '%{url_effective}' "https://github.com/$repo/releases/latest"
        if ("$final" -match '/releases/tag/(.+)$') { return [Uri]::UnescapeDataString($Matches[1]) }
    }
    throw "Couldn't find the latest release of $repo"
}

# git: this PC's, or a portable MinGit in the tools folder
function Get-Git {
    $git = Get-Command git.exe -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($git) { return $git.Source }
    $exe = Join-Path $script:toolsDir 'MinGit\cmd\git.exe'
    if (-not (Test-Path -LiteralPath $exe)) {
        Say 'Getting a portable Git (MinGit)...'
        $release = Get-Text 'https://api.github.com/repos/git-for-windows/git/releases/latest' | ConvertFrom-Json
        $asset = $release.assets | Where-Object { $_.name -match '^MinGit-[\d.]+-64-bit\.zip$' } | Select-Object -First 1
        if (-not $asset) { throw "Couldn't find MinGit in Git for Windows' latest release" }
        $zip = Join-Path $script:toolsDir 'MinGit.zip'
        Get-File $asset.browser_download_url $zip
        [IO.Compression.ZipFile]::ExtractToDirectory($zip, (Join-Path $script:toolsDir 'MinGit'))
        Remove-Item -LiteralPath $zip
    }
    return $exe
}

# a shallow clone of one tag or branch (with its submodules, when asked)
function Get-GitSource([string]$url, [string]$ref, [string]$to, [switch]$Submodules) {
    $git = Get-Git
    Say "Getting the source ($ref) from $url..."
    # (core.longpaths: many repos have paths longer than Windows' usual 260 characters; it's passed on to submodules)
    $gitArgs = @('-c', 'advice.detachedHead=false', '-c', 'core.longpaths=true', 'clone', '--depth', '1', '--branch', $ref)
    if ($Submodules) { $gitArgs += @('--recurse-submodules', '--shallow-submodules') }
    Invoke-Checked $git @gitArgs $url $to
}

# 7-Zip for archives .NET can't open (7z, tar.xz, ...): this PC's, or the standalone 7za in the tools folder
function Get-SevenZip {
    foreach ($candidate in @("$env:ProgramFiles\7-Zip\7z.exe", "${env:ProgramFiles(x86)}\7-Zip\7z.exe")) { if (Test-Path -LiteralPath $candidate) { return $candidate } }
    $exe = Join-Path $script:toolsDir '7za\7za.exe'
    if (-not (Test-Path -LiteralPath $exe)) {
        $page = Get-Text 'https://www.7-zip.org/download.html'
        $m = [regex]::Match($page, 'a/(7z\d+-extra\.7z)')
        if (-not $m.Success) { throw "Couldn't find 7-Zip's standalone version on 7-zip.org" }
        $sevenZr = Join-Path $script:toolsDir '7za\7zr.exe'
        Get-File 'https://www.7-zip.org/a/7zr.exe' $sevenZr
        $extra = Join-Path $script:toolsDir "7za\$($m.Groups[1].Value)"
        Get-File "https://www.7-zip.org/a/$($m.Groups[1].Value)" $extra
        Invoke-Checked $sevenZr x $extra "-o$(Join-Path $script:toolsDir '7za\x')" -y | Out-Null
        Copy-Item -LiteralPath (Join-Path $script:toolsDir '7za\x\x64\7za.exe') -Destination $exe
        Copy-Item -Path (Join-Path $script:toolsDir '7za\x\x64\7za.dll'), (Join-Path $script:toolsDir '7za\x\x64\7zxa.dll') -Destination (Split-Path $exe) -ErrorAction SilentlyContinue
    }
    return $exe
}

# (zips too: .NET's own unzipping skips files whose paths go over 260 characters)
function Expand-Archive7([string]$archive, [string]$to) {
    $sevenZip = Get-SevenZip
    if ($archive -match '\.tar\.(gz|xz|bz2|zst)$|\.t[gx]z$') {
        $tarDir = Join-Path (Split-Path -Parent $archive) "_untar_$([IO.Path]::GetFileNameWithoutExtension($archive))"
        Invoke-Checked $sevenZip x $archive "-o$tarDir" -y | Out-Null
        $tar = Get-ChildItem -LiteralPath $tarDir -Filter '*.tar' | Select-Object -First 1
        Invoke-Checked $sevenZip x $tar.FullName "-o$to" -y | Out-Null
        Remove-Item -LiteralPath $tarDir -Recurse -Force
    }
    else { Invoke-Checked $sevenZip x $archive "-o$to" -y | Out-Null }
}

# ---------------------------------------------------------------------------------------------
# Visual Studio
# ---------------------------------------------------------------------------------------------

# loads a Visual Studio's build environment (cl, msbuild, the Windows SDK) into this script, like its Developer
# Command Prompt. -Version picks a range (eg. '[17.0,18.0)' for Visual Studio 2022, which most projects target);
# -Components are the parts it must have (default: the C++ tools). Missing: says what to install, or installs
# Visual Studio 2022 Build Tools with winget (asks first, unless -Yes; needs admin).
function Use-VisualStudio([string]$Arch = 'x64', [string]$Version, [string[]]$Components = @('Microsoft.VisualStudio.Component.VC.Tools.x86.x64')) {
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    # (vcvarsall runs vswhere itself, so it's put on the PATH)
    Add-ToPath (Split-Path -Parent $vswhere)
    $find = {
        if (-not (Test-Path -LiteralPath $vswhere)) { return $null }
        $q = @('-products', '*', '-requires') + $Components + @('-property', 'installationPath', '-sort')
        if ($Version) { $q = @('-version', $Version) + $q }
        & $vswhere @q | Select-Object -First 1
    }
    $vs = & $find
    if (-not $vs) {
        $vsName = if ($Version -like '`[17.*') { 'Visual Studio 2022' } elseif ($Version -like '`[18.*') { 'Visual Studio 2026' } else { 'Visual Studio' }
        $what = "$vsName with: $($Components -join ', ')"
        Say "This build needs $what."
        # (the Build Tools winget offers are Visual Studio 2022's, so only when that version will do)
        $winget = if (-not $Version -or $Version -like '`[17.*') { Get-Command winget.exe -ErrorAction SilentlyContinue }
        $answer = if ($Yes) { 'y' } elseif ($winget) { Read-Host 'Install Visual Studio 2022 Build Tools with those parts now (several GB, asks for admin)? [y/N]' } else { 'n' }
        if ($answer -match '^y' -and $winget) {
            $add = ($Components | ForEach-Object { "--add $_" }) -join ' '
            & $winget.Source install --id Microsoft.VisualStudio.2022.BuildTools -e --accept-package-agreements --accept-source-agreements --override "--quiet --wait --norestart --includeRecommended $add"
            $vs = & $find
        }
        if (-not $vs) { Fail "Install $what (Visual Studio Installer > Modify), then run build.cmd again" }
    }
    $vcvars = Join-Path $vs 'VC\Auxiliary\Build\vcvarsall.bat'
    if (-not (Test-Path -LiteralPath $vcvars)) { Fail "Visual Studio at $vs has no C++ build tools (vcvarsall.bat)" }
    $hostArch = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'arm64' } else { 'x64' }
    $target = if ($Arch -eq $hostArch) { $Arch } else { "${hostArch}_$Arch" }
    Say "Using $(Split-Path -Leaf (Split-Path -Parent (Split-Path -Parent $vs))) $(Split-Path -Leaf (Split-Path -Parent $vs)) $(Split-Path -Leaf $vs) for $Arch"
    $lines = & cmd.exe /d /c "`"$vcvars`" $target >nul && set"
    if ($LASTEXITCODE -ne 0) { Fail "Couldn't load Visual Studio's build environment ($vcvars $target)" }
    foreach ($line in $lines) { if ($line -match '^([^=]+)=(.*)$') { Set-Item -Path "Env:$($Matches[1])" -Value $Matches[2] } }
    $script:vsPath = $vs
    return $vs
}

# ---------------------------------------------------------------------------------------------
# MSYS2 (MinGW compilers and libraries), in the tools folder
# ---------------------------------------------------------------------------------------------

$script:msysDir = Join-Path $script:toolsDir 'msys64'

function Invoke-Msys2([string]$Env = 'mingw64', [string]$Command, [string]$Dir) {
    $bash = Join-Path $script:msysDir 'usr\bin\bash.exe'
    $saved = @{ MSYSTEM = $env:MSYSTEM; CHERE_INVOKING = $env:CHERE_INVOKING; MSYS2_PATH_TYPE = $env:MSYS2_PATH_TYPE }
    $env:MSYSTEM = $Env.ToUpper(); $env:CHERE_INVOKING = '1'; $env:MSYS2_PATH_TYPE = 'minimal'
    Push-Location -LiteralPath $(if ($Dir) { $Dir } else { $script:Work })
    # (run from a script file: Windows PowerShell drops any " inside a command passed to bash -lc)
    $file = Join-Path $script:toolsDir "msys2-command-$PID.sh"
    [IO.File]::WriteAllText($file, ($Command -replace "`r`n", "`n") + "`n")
    try {
        & $bash -l ($file -replace '\\', '/')
        if ($LASTEXITCODE -ne 0) { throw "MSYS2 ($Env) command failed (exit code $LASTEXITCODE): $Command" }
    }
    finally {
        Remove-Item -LiteralPath $file -ErrorAction SilentlyContinue
        Pop-Location
        foreach ($k in $saved.Keys) { if ($null -eq $saved[$k]) { Remove-Item "Env:$k" -ErrorAction SilentlyContinue } else { Set-Item -Path "Env:$k" -Value $saved[$k] } }
    }
}

# a portable MSYS2, updated, with these packages (eg. mingw-w64-x86_64-gcc)
function Use-Msys2([string[]]$Packages) {
    $bash = Join-Path $script:msysDir 'usr\bin\bash.exe'
    if (-not (Test-Path -LiteralPath $bash)) {
        Say 'Getting a portable MSYS2 (the MinGW compilers and libraries)...'
        $sfx = Join-Path $script:toolsDir 'msys2-base.sfx.exe'
        Get-File 'https://repo.msys2.org/distrib/msys2-x86_64-latest.sfx.exe' $sfx
        Invoke-Checked $sfx -y "-o$($script:toolsDir)\" | Out-Null
        Remove-Item -LiteralPath $sfx
        # (its first start sets up the package keys; then the core and everything else are updated)
        Invoke-Msys2 -Env msys -Command 'true' -Dir $script:toolsDir
        # (the first update can stop part-way to restart its own runtime, so it's run again)
        try { Invoke-Msys2 -Env msys -Command 'pacman -Syuu --noconfirm' -Dir $script:toolsDir } catch { Say 'MSYS2 updated its core; updating the rest...' }
    }
    Invoke-Msys2 -Env msys -Command 'pacman -Syuu --noconfirm' -Dir $script:toolsDir
    if ($Packages) { Invoke-Msys2 -Env msys -Command "pacman -S --needed --noconfirm $($Packages -join ' ')" -Dir $script:toolsDir }
}

# ---------------------------------------------------------------------------------------------
# Other toolchains: this PC's when it has one new enough, or a portable copy in the tools folder
# ---------------------------------------------------------------------------------------------

function Add-ToPath([string]$dir) { if (($env:PATH -split ';') -notcontains $dir) { $env:PATH = "$dir;$env:PATH" } }

# -Version: the oldest version that will do (eg. '1.22'), or for dotnet the SDK channel (eg. '8.0')
function Use-Tool([string]$Name, [string]$Version) {
    # (Continue: some tools, eg. java -version, write their version to stderr, which would stop the build otherwise)
    $have = { param($exe, $verArgs, $pattern) $ErrorActionPreference = 'Continue'; $c = Get-Command $exe -ErrorAction SilentlyContinue | Select-Object -First 1; if (-not $c) { return $null }; $out = (& $c.Source @verArgs 2>&1 | Out-String); $m = [regex]::Match($out, $pattern); if ($m.Success) { [pscustomobject]@{ Path = $c.Source; Version = $m.Groups[1].Value } } }
    $newEnough = { param($found) if (-not $found) { return $false }; if (-not $Version) { return $true }; try { return [version]($found.Version -replace '^(\d+(\.\d+){0,3}).*', '$1') -ge [version]($Version + $(if ($Version -notmatch '\.') { '.0' })) } catch { return $true } }
    switch ($Name) {
        'go' {
            if (& $newEnough (& $have go.exe @('version') 'go(\d+\.\d+(\.\d+)?)')) { return }
            $dir = Join-Path $script:toolsDir 'go'
            if (-not (Test-Path -LiteralPath "$dir\bin\go.exe")) {
                $rel = (Get-Text 'https://go.dev/dl/?mode=json' | ConvertFrom-Json)[0]
                $file = $rel.files | Where-Object { $_.os -eq 'windows' -and $_.arch -eq 'amd64' -and $_.kind -eq 'archive' } | Select-Object -First 1
                Say "Getting a portable Go ($($rel.version))..."
                $zip = Join-Path $script:toolsDir $file.filename; Get-File "https://go.dev/dl/$($file.filename)" $zip
                [IO.Compression.ZipFile]::ExtractToDirectory($zip, $script:toolsDir); Remove-Item -LiteralPath $zip
            }
            Add-ToPath "$dir\bin"
        }
        'node' {
            if (& $newEnough (& $have node.exe @('--version') 'v(\d+\.\d+\.\d+)')) { return }
            $dir = Get-ChildItem -LiteralPath $script:toolsDir -Directory -Filter 'node-v*-win-x64' -ErrorAction SilentlyContinue | Select-Object -First 1
            if (-not $dir) {
                $rel = (Get-Text 'https://nodejs.org/dist/index.json' | ConvertFrom-Json) | Where-Object { $_.lts } | Select-Object -First 1
                Say "Getting a portable Node.js ($($rel.version))..."
                $zip = Join-Path $script:toolsDir "node-$($rel.version)-win-x64.zip"; Get-File "https://nodejs.org/dist/$($rel.version)/node-$($rel.version)-win-x64.zip" $zip
                [IO.Compression.ZipFile]::ExtractToDirectory($zip, $script:toolsDir); Remove-Item -LiteralPath $zip
                $dir = Get-ChildItem -LiteralPath $script:toolsDir -Directory -Filter 'node-v*-win-x64' | Select-Object -First 1
            }
            Add-ToPath $dir.FullName
        }
        'dotnet' {
            # -Version is the SDK channel (eg. '8.0'), or an exact SDK (eg. '11.0.100') for a project that needs that one;
            # this PC's dotnet counts when it has an SDK in that channel or newer (or that exact one)
            $exact = $Version -match '^\d+\.\d+\.\d+'
            $c = Get-Command dotnet.exe -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($c) {
                $sdks = @(& $c.Source --list-sdks 2>$null | ForEach-Object { ($_ -split ' ')[0] })
                if ($exact) { if ($sdks -contains $Version) { return } }
                elseif ($sdks | Where-Object { -not $Version -or [version]($_ -replace '-.*') -ge [version]"$Version.0" }) { return }
            }
            $dir = Join-Path $script:toolsDir 'dotnet'
            if (-not (Test-Path -LiteralPath "$dir\dotnet.exe") -or -not (@(& "$dir\dotnet.exe" --list-sdks 2>$null) -match "^$([regex]::Escape($Version))")) {
                Say "Getting a portable .NET SDK ($Version)..."
                $script = Join-Path $script:toolsDir 'dotnet-install.ps1'; Get-File 'https://dot.net/v1/dotnet-install.ps1' $script
                $which = if ($exact) { @('-Version', $Version) } else { @('-Channel', $Version) }
                & powershell -NoProfile -ExecutionPolicy Bypass -File $script @which -InstallDir $dir -NoPath
                if ($LASTEXITCODE -ne 0) { throw "Couldn't get the .NET $Version SDK" }
            }
            Add-ToPath $dir; $env:DOTNET_ROOT = $dir; $env:DOTNET_MULTILEVEL_LOOKUP = '0'
        }
        'ninja' {
            if (Get-Command ninja.exe -ErrorAction SilentlyContinue) { return }
            $dir = Join-Path $script:toolsDir 'ninja'
            if (-not (Test-Path -LiteralPath "$dir\ninja.exe")) {
                $zip = Join-Path $script:toolsDir 'ninja-win.zip'; Get-File 'https://github.com/ninja-build/ninja/releases/latest/download/ninja-win.zip' $zip
                [IO.Compression.ZipFile]::ExtractToDirectory($zip, $dir); Remove-Item -LiteralPath $zip
            }
            Add-ToPath $dir
        }
        'jdk' {
            # -Version is the major version (eg. '21')
            $major = if ($Version) { $Version } else { '21' }
            $found = & $have java.exe @('-version') 'version "(\d+)'
            if ($found -and [int]$found.Version -ge [int]$major -and $env:JAVA_HOME) { return }
            if ($found -and [int]$found.Version -ge [int]$major) { $env:JAVA_HOME = Split-Path -Parent (Split-Path -Parent $found.Path); return }
            $dir = Get-ChildItem -LiteralPath $script:toolsDir -Directory -Filter "jdk-$major*" -ErrorAction SilentlyContinue | Select-Object -First 1
            if (-not $dir) {
                Say "Getting a portable JDK $major (Eclipse Temurin)..."
                $zip = Join-Path $script:toolsDir "jdk$major.zip"; Get-File "https://api.adoptium.net/v3/binary/latest/$major/ga/windows/x64/jdk/hotspot/normal/eclipse" $zip
                [IO.Compression.ZipFile]::ExtractToDirectory($zip, $script:toolsDir); Remove-Item -LiteralPath $zip
                $dir = Get-ChildItem -LiteralPath $script:toolsDir -Directory -Filter "jdk-$major*" | Select-Object -First 1
            }
            $env:JAVA_HOME = $dir.FullName; Add-ToPath "$($dir.FullName)\bin"
        }
        'python' {
            if (& $newEnough (& $have python.exe @('--version') 'Python (\d+\.\d+(\.\d+)?)')) { return }
            # (the full Python from its NuGet package: no installer, and it has pip and venv)
            $dir = Join-Path $script:toolsDir 'python'
            if (-not (Test-Path -LiteralPath "$dir\tools\python.exe")) {
                Say 'Getting a portable Python...'
                $zip = Join-Path $script:toolsDir 'python.zip'; Get-File 'https://www.nuget.org/api/v2/package/python' $zip
                [IO.Compression.ZipFile]::ExtractToDirectory($zip, $dir); Remove-Item -LiteralPath $zip
            }
            Add-ToPath "$dir\tools\Scripts"; Add-ToPath "$dir\tools"
        }
        'rust' {
            if (Get-Command cargo.exe -ErrorAction SilentlyContinue) { return }
            $env:RUSTUP_HOME = Join-Path $script:toolsDir 'rustup'; $env:CARGO_HOME = Join-Path $script:toolsDir 'cargo'
            if (-not (Test-Path -LiteralPath "$env:CARGO_HOME\bin\cargo.exe")) {
                Say 'Getting a portable Rust (rustup)...'
                $init = Join-Path $script:toolsDir 'rustup-init.exe'; Get-File 'https://static.rust-lang.org/rustup/dist/x86_64-pc-windows-msvc/rustup-init.exe' $init
                Invoke-Checked $init -y --no-modify-path --profile minimal
            }
            Add-ToPath "$env:CARGO_HOME\bin"
        }
        default { throw "Use-Tool doesn't know '$Name'" }
    }
}

# the Node.js version a project pins (eg. '24' for the newest 24.x, or '24.22.1'): this PC's when it's that one,
# otherwise a portable copy from nodejs.org in the tools folder (in node-versions, apart from Use-Tool node's).
# Also keeps the npm / node-gyp / Electron download caches in the tools folder, not in the PC's user profile.
function Use-NodeVersion([string]$Wanted) {
    $Wanted = $Wanted.Trim() -replace '^v'
    $matchesWanted = { param($v) $v = $v -replace '^v'; $v -eq $Wanted -or $v -like "$Wanted.*" }
    $pc = Get-Command node.exe -ErrorAction SilentlyContinue | Select-Object -First 1
    $have = if ($pc) { (& $pc.Source --version 2>$null | Out-String).Trim() }
    if (-not ($have -and (& $matchesWanted $have))) {
        $base = Join-Path $script:toolsDir 'node-versions'
        # (ForEach-Object unrolls the JSON array, which Windows PowerShell 5.1 passes on as one object)
        $index = @(Get-Text 'https://nodejs.org/dist/index.json' | ConvertFrom-Json) | ForEach-Object { $_ }
        $release = $index | Where-Object { & $matchesWanted $_.version } | Select-Object -First 1
        if (-not $release) { throw "Couldn't find Node.js $Wanted on nodejs.org" }
        $dir = Join-Path $base "node-$($release.version)-win-x64"
        if (-not (Test-Path -LiteralPath "$dir\node.exe")) {
            Say "Getting a portable Node.js ($($release.version))..."
            $zip = Join-Path $base "node-$($release.version)-win-x64.zip"
            Get-File "https://nodejs.org/dist/$($release.version)/node-$($release.version)-win-x64.zip" $zip
            [IO.Compression.ZipFile]::ExtractToDirectory($zip, $base); Remove-Item -LiteralPath $zip
        }
        Add-ToPath $dir
        # (npm's global folder in it too, eg. for corepack's yarn)
        $env:npm_config_prefix = $dir
    }
    Say "Using Node.js $((& node --version | Out-String).Trim())"
    $env:npm_config_cache = Join-Path $script:toolsDir 'npm-cache'
    $env:npm_config_devdir = Join-Path $script:toolsDir 'node-gyp'
    $env:electron_config_cache = Join-Path $script:toolsDir 'electron-cache'
    $env:npm_config_update_notifier = 'false'
    $env:npm_config_fund = 'false'
    $env:npm_config_audit = 'false'
}

# ---------------------------------------------------------------------------------------------
# The result
# ---------------------------------------------------------------------------------------------

# copies the build into Built\<arch> (replacing an older build there) with a build.txt saying what it is
function Publish-Build([string]$From, [string]$Arch = 'x64', [string]$Version, [string[]]$Files, [string]$Note) {
    if (-not (Test-Path -LiteralPath $From)) { throw "The build didn't make $From" }
    $target = Join-Path $script:appDir "Built\$Arch"
    if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Recurse -Force }
    New-Item -ItemType Directory -Path $target -Force | Out-Null
    if ((Get-Item -LiteralPath $From).PSIsContainer) {
        if ($Files) { foreach ($f in $Files) { Copy-Item -Path (Join-Path $From $f) -Destination $target -Recurse -Force } }
        else { Copy-Item -Path (Join-Path $From '*') -Destination $target -Recurse -Force }
    }
    else { Copy-Item -LiteralPath $From -Destination $target -Force }
    $info = @(
        "$($script:appName) $Version, built from source on $(Get-Date -Format 'yyyy-MM-dd HH:mm') by $(Split-Path -Leaf $MyInvocation.PSCommandPath) / build.cmd"
        "Computer: $env:COMPUTERNAME ($env:PROCESSOR_ARCHITECTURE)$(if ($script:vsPath) { "; Visual Studio: $($script:vsPath)" })"
    )
    if ($Note) { $info += $Note }
    [IO.File]::WriteAllText((Join-Path $target 'build.txt'), (($info -join "`r`n") + "`r`n"))
    Say "Copied the build to $target"
    $script:published += @($target)
}
$script:published = @()

function Complete-Build {
    if ($script:Work -and -not $KeepWork -and (Test-Path -LiteralPath $script:Work)) {
        Set-Location -LiteralPath $env:TEMP
        Remove-Item -LiteralPath $script:Work -Recurse -Force -ErrorAction SilentlyContinue
    }
    Say ''
    $took = if ($script:buildStarted) { [int]((Get-Date) - $script:buildStarted).TotalMinutes } else { 0 }
    Say "Done in $took minute$(if ($took -ne 1) { 's' }): $($script:appName) is in $($script:published -join ', ')"
    if ($KeepWork) { Say "(the source and build files are kept in $($script:Work))" }
}
