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
#   -WorkDir <folder>  the folder to build in: the source and the build go in their own <folder>\<app> (default
#                      %TEMP%\USB-Tool-Build\<app>, or _Data\Temp\Build-<app> on the USB when the PC's drive is too
#                      full, with the portable tools in _Data\Temp\Build-_tools then). Only folders the build made
#                      (with a USB-Tool-Build.txt in them) are ever removed.
#   -KeepWork          keep the work folder afterwards (eg. to look at the build files; the next build starts afresh)
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
# Portable toolchains are kept between builds in %TEMP%\USB-Tool-Build\_tools, so the next build is faster (MSYS2 in
# %SystemDrive%\USB-Tool-Build\msys64 instead when that path has spaces or non-ASCII characters, which MSYS2 can't use).
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
# (in each work folder the build makes, so only those are ever removed)
$script:workMarker = 'USB-Tool-Build.txt'
Add-Type -AssemblyName System.IO.Compression.FileSystem

# the tools folder, and MSYS2's folder in it; MSYS2 doesn't work in a path with spaces or non-ASCII characters (as
# %TEMP% has for a user name like that; ~ is an 8.3 short name standing in for one), so it's in
# %SystemDrive%\USB-Tool-Build then
function Set-ToolsRoot([string]$dir) {
    $script:toolsDir = $dir
    $script:msysDir = Join-Path $dir 'msys64'
    if ($script:msysDir -notmatch '^[A-Za-z]:\\[A-Za-z0-9_.\\-]+$') { $script:msysDir = Join-Path "$env:SystemDrive\" 'USB-Tool-Build\msys64' }
}
Set-ToolsRoot (Join-Path $script:buildRoot '_tools')

function Say([string]$message) { Write-Host $message }
function Fail([string]$message) { Say ''; Say "FAILED: $message"; exit 1 }

# a build.ps1's "trap { Stop-Build $_ }": anything that goes wrong ends the build with what it was, keeping the
# work folder to look at (a trap only covers the script it's in, so each build.ps1 has its own)
function Stop-Build($errorRecord) {
    Say ''
    Say "FAILED: $($errorRecord.Exception.Message)"
    if ($script:Work -and (Test-Path -LiteralPath $script:Work)) { Say "(the source and build files are in $($script:Work); build.cmd removes them next time)" }
    Say "(the portable tools are kept in $($script:toolsDir) for the next builds; if one of them is broken, eg. after its download was cut off, delete its folder there)"
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

# removes a work folder, but only one the build made: with the marker file in it, or (-Ours) at one of the build's own
# places, which earlier builds made without the marker; never a drive's root or the user profile (or a folder holding it)
function Remove-WorkFolder([string]$dir, [switch]$Ours) {
    if (-not $dir -or -not (Test-Path -LiteralPath $dir)) { return }
    $full = [IO.Path]::GetFullPath($dir).TrimEnd('\')
    $marker = Join-Path $full $script:workMarker
    $userProfile = [IO.Path]::GetFullPath($env:USERPROFILE).TrimEnd('\')
    if ($full.Length -le 3 -or "$userProfile\".StartsWith("$full\", [StringComparison]::OrdinalIgnoreCase) -or -not ($Ours -or (Test-Path -LiteralPath $marker))) {
        throw "Not removing $full, as it isn't a work folder a build made"
    }
    Remove-Item -LiteralPath $full -Recurse -Force -ErrorAction SilentlyContinue
    # (when something still has files open in it, it stays marked as the build's, for the next build to remove)
    if (Test-Path -LiteralPath $full) { [IO.File]::WriteAllText($marker, "Made by a USB-Tool build.cmd; the next build removes it.`r`n") }
}

# the work folder: <-WorkDir>\<app>, %TEMP%\USB-Tool-Build\<app>, or _Data\Temp\Build-<app> on the USB when the PC's
# drive is too full (the tools folder then moves to the USB too, as the toolchains need space as well)
function Start-Build([string]$Name, [int]$NeedGB = 2) {
    $script:appName = $Name
    $script:appDir = Split-Path -Parent $MyInvocation.PSCommandPath
    if (-not $script:appDir) { $script:appDir = $PSScriptRoot }
    $folderName = $Name -replace '[\\/:*?"<>|]', '_'
    # (_Data\Temp: up from the app's folder to _Data\Apps, for apps in a group folder too)
    $apps = $script:appDir; while ($apps -and (Split-Path -Leaf $apps) -ne 'Apps') { $apps = Split-Path -Parent $apps }
    $usbTemp = if ($apps) { Join-Path (Split-Path -Parent $apps) 'Temp' }
    $defaultDir = Join-Path $script:buildRoot $folderName
    $usbDir = if ($usbTemp) { Join-Path $usbTemp "Build-$folderName" }
    # (an earlier build's work folder goes first, wherever it was: a kept one, or one left on the USB by a build when the
    # PC's drive was full, may be what's filling a drive)
    foreach ($old in @($defaultDir, $usbDir)) { Remove-WorkFolder $old -Ours }
    if ($WorkDir) {
        # (the build gets its own folder in -WorkDir, so nothing else there is touched; resolved to a full path now, as
        # the current folder changes during the build)
        $dir = Join-Path $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($WorkDir) $folderName
        if (Test-Path -LiteralPath $dir) {
            if (-not (Test-Path -LiteralPath (Join-Path $dir $script:workMarker))) { Fail "$dir is already there, and isn't a work folder a build made, so it's left alone; use another -WorkDir" }
            Remove-WorkFolder $dir
        }
    }
    else {
        $dir = $defaultDir
        if ((Get-FreeSpace $env:TEMP) -lt $NeedGB * 1GB) {
            if ($usbTemp -and (Get-FreeSpace $usbTemp) -ge $NeedGB * 1GB) {
                $dir = $usbDir
                Set-ToolsRoot (Join-Path $usbTemp 'Build-_tools')
                Say "Not enough space in $env:TEMP, so building in $dir, with the portable tools in $($script:toolsDir) (slower; any not there yet are downloaded again)"
            }
            else { Fail "Building $Name needs about $NeedGB GB free (in $env:TEMP or on the USB); use -WorkDir to build somewhere else" }
        }
    }
    if (Test-Path -LiteralPath $dir) { Fail "Couldn't remove the earlier build's $dir (a program may still have files open in it)" }
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    [IO.File]::WriteAllText((Join-Path $dir $script:workMarker), "Made by a USB-Tool build.cmd for $Name; removed when the build is done (unless -KeepWork) or by the next build.`r`n")
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

# the newest release's tag (from the API, or the releases pages when its hourly limit has run out)
# -Pre: a pre-release will do too; -Match: only a tag that matches this regex
function Get-LatestGitHubTag([string]$repo, [switch]$Pre, [string]$Match) {
    $wanted = { param($tag, $isPre) ($Pre -or -not $isPre) -and (-not $Match -or $tag -match $Match) }
    try {
        if ($Pre -or $Match) {
            $all = @(Get-Text "https://api.github.com/repos/$repo/releases?per_page=50" | ConvertFrom-Json) | ForEach-Object { $_ }
            $pick = $all | Where-Object { -not $_.draft -and (& $wanted $_.tag_name $_.prerelease) } | Select-Object -First 1
            if ($pick) { return $pick.tag_name }
        }
        else { return (Get-Text "https://api.github.com/repos/$repo/releases/latest" | ConvertFrom-Json).tag_name }
    }
    catch {
        if (-not ($Pre -or $Match)) {
            $final = & $script:curl -sSIL --fail -o NUL -w '%{url_effective}' "https://github.com/$repo/releases/latest"
            if ("$final" -match '/releases/tag/(.+)$') { return [Uri]::UnescapeDataString($Matches[1]) }
        }
        else {
            # (not /releases/latest, which is the newest full release whatever its tag, eg. Bitwarden's web or cli one,
            # but the releases page: its newest 10, each in a <section> with a Pre-release label when it is one)
            $page = Get-Text "https://github.com/$repo/releases"
            $seen = 0
            foreach ($section in @($page -split '<section\b' | Select-Object -Skip 1)) {
                $m = [regex]::Match($section, "href=`"/$([regex]::Escape($repo))/releases/tag/([^`"]+)`"", 'IgnoreCase')
                if (-not $m.Success) { continue }
                $seen++
                $tag = [Uri]::UnescapeDataString([Net.WebUtility]::HtmlDecode($m.Groups[1].Value))
                if (& $wanted $tag ($section -match 'class="Label[^"]*"[^>]*>\s*Pre-release\s*<')) { return $tag }
            }
            $what = "a$(if (-not $Pre) { ' full' }) release of $repo$(if ($Match) { " with a tag matching $Match" })"
            if (-not $seen) { throw "Couldn't find $what (GitHub's API limit has run out, and its releases page has changed); try again in an hour, or give the -Version" }
            throw "Couldn't find $what in the newest $seen on its releases page (GitHub's API limit has run out); try again in an hour, or give the -Version"
        }
    }
    throw "Couldn't find the latest release of $repo"
}

# unzips a downloaded tool into its folder (replacing what's there), by way of a temporary folder that's renamed into
# place once it's complete: so a cut-off download or unzip never leaves a half-made tool folder behind, which later
# builds would use as it is, or fail to unzip over. -Inner: the zip has it all in one folder of its own (eg. go\).
function Expand-ToolZip([string]$zip, [string]$to, [switch]$Inner) {
    $tmp = "$to.partial"
    if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    [IO.Compression.ZipFile]::ExtractToDirectory($zip, $tmp)
    $from = if ($Inner) { @(Get-ChildItem -LiteralPath $tmp -Directory)[0].FullName } else { $tmp }
    if (Test-Path -LiteralPath $to) { Remove-Item -LiteralPath $to -Recurse -Force }
    Move-Item -LiteralPath $from -Destination $to
    if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    Remove-Item -LiteralPath $zip
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
        Expand-ToolZip $zip (Join-Path $script:toolsDir 'MinGit')
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
        # (7za.exe last, as it's what says this is done)
        Copy-Item -Path (Join-Path $script:toolsDir '7za\x\x64\7za.dll'), (Join-Path $script:toolsDir '7za\x\x64\7zxa.dll') -Destination (Split-Path $exe) -ErrorAction SilentlyContinue
        Copy-Item -LiteralPath (Join-Path $script:toolsDir '7za\x\x64\7za.exe') -Destination $exe
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
# MSYS2 (MinGW compilers and libraries), in the tools folder ($script:msysDir, see Set-ToolsRoot)
# ---------------------------------------------------------------------------------------------

function Invoke-Msys2([string]$Env = 'mingw64', [string]$Command, [string]$Dir) {
    $bash = Join-Path $script:msysDir 'usr\bin\bash.exe'
    $saved = @{ MSYSTEM = $env:MSYSTEM; CHERE_INVOKING = $env:CHERE_INVOKING; MSYS2_PATH_TYPE = $env:MSYS2_PATH_TYPE }
    $env:MSYSTEM = $Env.ToUpper(); $env:CHERE_INVOKING = '1'; $env:MSYS2_PATH_TYPE = 'minimal'
    Push-Location -LiteralPath $(if ($Dir) { $Dir } else { $script:Work })
    # (run from a script file: Windows PowerShell drops any " inside a command passed to bash -lc; in MSYS2's own tmp,
    # whose path is one it can use)
    $file = Join-Path $script:msysDir "tmp\usb-tool-command-$PID.sh"
    New-Item -ItemType Directory -Path (Split-Path -Parent $file) -Force | Out-Null
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
        Say "Getting a portable MSYS2 (the MinGW compilers and libraries) into $($script:msysDir)..."
        $sfx = Join-Path $script:toolsDir 'msys2-base.sfx.exe'
        Get-File 'https://repo.msys2.org/distrib/msys2-x86_64-latest.sfx.exe' $sfx
        # (unpacked beside it and then renamed into place, so a cut-off one isn't taken for a whole one next time)
        $tmp = "$($script:msysDir).partial"
        if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
        Invoke-Checked $sfx -y "-o$tmp\" | Out-Null
        if (Test-Path -LiteralPath $script:msysDir) { Remove-Item -LiteralPath $script:msysDir -Recurse -Force }
        Move-Item -LiteralPath (Join-Path $tmp 'msys64') -Destination $script:msysDir
        Remove-Item -LiteralPath $tmp -Recurse -Force
        Remove-Item -LiteralPath $sfx
        # (its first start sets up the package keys; then the core and everything else are updated)
        Invoke-Msys2 -Env msys -Command 'true' -Dir $script:msysDir
        # (the first update can stop part-way to restart its own runtime, so it's run again)
        try { Invoke-Msys2 -Env msys -Command 'pacman -Syuu --noconfirm' -Dir $script:msysDir } catch { Say 'MSYS2 updated its core; updating the rest...' }
    }
    Invoke-Msys2 -Env msys -Command 'pacman -Syuu --noconfirm' -Dir $script:msysDir
    if ($Packages) { Invoke-Msys2 -Env msys -Command "pacman -S --needed --noconfirm $($Packages -join ' ')" -Dir $script:msysDir }
}

# ---------------------------------------------------------------------------------------------
# Other toolchains: this PC's when it has one new enough, or a portable copy in the tools folder
# ---------------------------------------------------------------------------------------------

function Add-ToPath([string]$dir) { if (($env:PATH -split ';') -notcontains $dir) { $env:PATH = "$dir;$env:PATH" } }

# -Version: the oldest version that will do (eg. '1.22'), or for dotnet the SDK channel (eg. '8.0')
function Use-Tool([string]$Name, [string]$Version) {
    # (Continue: some tools, eg. java -version, write their version to stderr, which would stop the build otherwise;
    # $exe can be a full path, eg. a portable one from an earlier build, which may not run when its unzip was cut off)
    $have = { param($exe, $verArgs, $pattern) $ErrorActionPreference = 'Continue'; $c = Get-Command $exe -ErrorAction SilentlyContinue | Select-Object -First 1; if (-not $c) { return $null }; try { $out = (& $c.Source @verArgs 2>&1 | Out-String) } catch { return $null }; $m = [regex]::Match($out, $pattern); if ($m.Success) { [pscustomobject]@{ Path = $c.Source; Version = $m.Groups[1].Value } } }
    $newEnough = { param($found) if (-not $found) { return $false }; if (-not $Version) { return $true }; try { return [version]($found.Version -replace '^(\d+(\.\d+){0,3}).*', '$1') -ge [version]($Version + $(if ($Version -notmatch '\.') { '.0' })) } catch { return $true } }
    switch ($Name) {
        'go' {
            $goVersion = 'go(\d+\.\d+(\.\d+)?)'
            if (& $newEnough (& $have go.exe @('version') $goVersion)) { return }
            $dir = Join-Path $script:toolsDir 'go'
            # (the portable one from an earlier build, when it's new enough for this one too)
            if (-not (& $newEnough (& $have "$dir\bin\go.exe" @('version') $goVersion))) {
                $rel = (Get-Text 'https://go.dev/dl/?mode=json' | ConvertFrom-Json)[0]
                $file = $rel.files | Where-Object { $_.os -eq 'windows' -and $_.arch -eq 'amd64' -and $_.kind -eq 'archive' } | Select-Object -First 1
                Say "Getting a portable Go ($($rel.version))..."
                $zip = Join-Path $script:toolsDir $file.filename; Get-File "https://go.dev/dl/$($file.filename)" $zip
                Expand-ToolZip $zip $dir -Inner
            }
            Add-ToPath "$dir\bin"
        }
        'node' {
            $nodeVersion = 'v(\d+\.\d+\.\d+)'
            if (& $newEnough (& $have node.exe @('--version') $nodeVersion)) { return }
            # (the newest portable one from an earlier build that's new enough; one without npx.cmd was cut off unzipping)
            $dir = Get-ChildItem -LiteralPath $script:toolsDir -Directory -Filter 'node-v*-win-x64' -ErrorAction SilentlyContinue |
                Where-Object { (Test-Path -LiteralPath "$($_.FullName)\npx.cmd") -and (& $newEnough (& $have "$($_.FullName)\node.exe" @('--version') $nodeVersion)) } |
                Sort-Object { try { [version]($_.Name -replace '^node-v|-win-x64$') } catch { [version]'0.0' } } -Descending | Select-Object -First 1
            if (-not $dir) {
                # (the newest LTS, or the newest of all when -Version is newer than that)
                $index = @(Get-Text 'https://nodejs.org/dist/index.json' | ConvertFrom-Json) | ForEach-Object { $_ }
                $usable = @($index | Where-Object { & $newEnough ([pscustomobject]@{ Version = $_.version -replace '^v' }) })
                $rel = @(@($usable | Where-Object { $_.lts }) + $usable)[0]
                if (-not $rel) { throw "Couldn't find Node.js $Version or newer on nodejs.org" }
                Say "Getting a portable Node.js ($($rel.version))..."
                $zip = Join-Path $script:toolsDir "node-$($rel.version)-win-x64.zip"; Get-File "https://nodejs.org/dist/$($rel.version)/node-$($rel.version)-win-x64.zip" $zip
                Expand-ToolZip $zip (Join-Path $script:toolsDir "node-$($rel.version)-win-x64") -Inner
                $dir = Get-Item -LiteralPath (Join-Path $script:toolsDir "node-$($rel.version)-win-x64")
            }
            Add-ToPath $dir.FullName
        }
        'dotnet' {
            # -Version is the SDK channel (eg. '8.0'), or an exact SDK (eg. '11.0.100') for a project that needs that one;
            # this PC's dotnet counts when it has an SDK in that channel or newer (or that exact one)
            $exact = $Version -match '^\d+\.\d+\.\d+'
            # (Continue: with Stop, any line dotnet writes to stderr, eg. a first-run notice, would stop the build)
            $listSdks = { param($exe) $ErrorActionPreference = 'Continue'; @(& $exe --list-sdks 2>$null | ForEach-Object { "$_" }) }
            $c = Get-Command dotnet.exe -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($c) {
                $sdks = @(& $listSdks $c.Source | ForEach-Object { ($_ -split ' ')[0] })
                if ($exact) { if ($sdks -contains $Version) { return } }
                elseif ($sdks | Where-Object { -not $Version -or [version]($_ -replace '-.*') -ge [version]"$Version.0" }) { return }
            }
            $dir = Join-Path $script:toolsDir 'dotnet'
            if (-not (Test-Path -LiteralPath "$dir\dotnet.exe") -or -not (@(& $listSdks "$dir\dotnet.exe") -match "^$([regex]::Escape($Version))")) {
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
                Expand-ToolZip $zip $dir
            }
            Add-ToPath $dir
        }
        'jdk' {
            # -Version is the major version (eg. '21'). JAVA_HOME (which gradlew goes by) must be a JDK's own folder, and
            # the java.exe on the PATH may be a launcher somewhere else (eg. Oracle's ...\Common Files\Oracle\Java\javapath),
            # so it's asked for its java.home; a JDK has javac.exe and a release file saying its version. A JDK 9 or newer
            # also has lib\modules, which an unzip that was cut off may not have got to.
            $major = if ($Version) { [int]$Version } else { 21 }
            $jdkMajor = { param($home_) if (-not $home_ -or -not (Test-Path -LiteralPath "$home_\bin\javac.exe") -or -not (Test-Path -LiteralPath "$home_\release")) { return 0 }
                $m = [regex]::Match([IO.File]::ReadAllText("$home_\release"), 'JAVA_VERSION="(?:1\.)?(\d+)')
                if (-not $m.Success) { return 0 }; $v = [int]$m.Groups[1].Value
                if ($v -ge 9 -and -not (Test-Path -LiteralPath "$home_\lib\modules")) { return 0 }; return $v }
            $useJdk = { param($home_) $env:JAVA_HOME = $home_.TrimEnd('\'); Add-ToPath "$($env:JAVA_HOME)\bin" }
            if ($env:JAVA_HOME) {
                if ((& $jdkMajor $env:JAVA_HOME) -ge $major) { & $useJdk $env:JAVA_HOME; return }
                Say "JAVA_HOME ($env:JAVA_HOME) isn't a JDK $major or newer, so this build uses another one"
            }
            $java = Get-Command java.exe -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($java) {
                $props = & { $ErrorActionPreference = 'Continue'; & $java.Source '-XshowSettings:properties' -version 2>&1 | ForEach-Object { "$_" } | Out-String }
                $m = [regex]::Match($props, '(?m)^\s*java\.home = (.+?)\s*$')
                if ($m.Success -and (& $jdkMajor $m.Groups[1].Value) -ge $major) { & $useJdk $m.Groups[1].Value; return }
            }
            $dir = Get-ChildItem -LiteralPath $script:toolsDir -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "^jdk-$major([.+]|$)" }
            $whole = $dir | Where-Object { (& $jdkMajor $_.FullName) -eq $major } | Select-Object -First 1
            if (-not $whole) {
                # (half-unzipped ones left by earlier builds)
                $dir | ForEach-Object { Remove-Item -LiteralPath $_.FullName -Recurse -Force }
                Say "Getting a portable JDK $major (Eclipse Temurin)..."
                $zip = Join-Path $script:toolsDir "jdk$major.zip"; Get-File "https://api.adoptium.net/v3/binary/latest/$major/ga/windows/x64/jdk/hotspot/normal/eclipse" $zip
                Expand-ToolZip $zip (Join-Path $script:toolsDir "jdk-$major") -Inner
                $whole = Get-Item -LiteralPath (Join-Path $script:toolsDir "jdk-$major")
            }
            & $useJdk $whole.FullName
        }
        'python' {
            $pythonVersion = 'Python (\d+\.\d+(\.\d+)?)'
            if (& $newEnough (& $have python.exe @('--version') $pythonVersion)) { return }
            # (the full Python from its NuGet package: no installer, and it has pip and venv; the one from an earlier build
            # when it's new enough for this one too, and whole: Lib\os.py is what it needs first)
            $dir = Join-Path $script:toolsDir 'python'
            if (-not ((Test-Path -LiteralPath "$dir\tools\Lib\os.py") -and (& $newEnough (& $have "$dir\tools\python.exe" @('--version') $pythonVersion)))) {
                Say 'Getting a portable Python...'
                $zip = Join-Path $script:toolsDir 'python.zip'; Get-File 'https://www.nuget.org/api/v2/package/python' $zip
                Expand-ToolZip $zip $dir
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
    # (Continue: with Stop, a line node writes to stderr, eg. a warning, would stop the build)
    $have = if ($pc) { & { $ErrorActionPreference = 'Continue'; (& $pc.Source --version 2>$null | Out-String).Trim() } }
    if (-not ($have -and (& $matchesWanted $have))) {
        $base = Join-Path $script:toolsDir 'node-versions'
        # (ForEach-Object unrolls the JSON array, which Windows PowerShell 5.1 passes on as one object)
        $index = @(Get-Text 'https://nodejs.org/dist/index.json' | ConvertFrom-Json) | ForEach-Object { $_ }
        $release = $index | Where-Object { & $matchesWanted $_.version } | Select-Object -First 1
        if (-not $release) { throw "Couldn't find Node.js $Wanted on nodejs.org" }
        $dir = Join-Path $base "node-$($release.version)-win-x64"
        # (one without npx.cmd was cut off unzipping)
        if (-not (Test-Path -LiteralPath "$dir\npx.cmd")) {
            Say "Getting a portable Node.js ($($release.version))..."
            $zip = Join-Path $base "node-$($release.version)-win-x64.zip"
            Get-File "https://nodejs.org/dist/$($release.version)/node-$($release.version)-win-x64.zip" $zip
            Expand-ToolZip $zip $dir -Inner
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
        # (out of it first, so it isn't the current folder; $script:Work is a full path, the folder Start-Build made)
        Set-Location -LiteralPath $env:TEMP
        try { Remove-WorkFolder $script:Work } catch { Say $_.Exception.Message }
        if (Test-Path -LiteralPath $script:Work) { Say "(couldn't remove all of $($script:Work), as something still has files open in it; the next build removes it)" }
    }
    Say ''
    $took = if ($script:buildStarted) { [int]((Get-Date) - $script:buildStarted).TotalMinutes } else { 0 }
    Say "Done in $took minute$(if ($took -ne 1) { 's' }): $($script:appName) is in $($script:published -join ', ')"
    if ($KeepWork) { Say "(the source and build files are kept in $($script:Work))" }
}
