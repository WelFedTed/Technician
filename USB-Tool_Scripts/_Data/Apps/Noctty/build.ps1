param([string]$Version, [string]$WorkDir, [switch]$KeepWork, [switch]$Yes)
. "$PSScriptRoot\..\_Build-App.ps1"
trap { Stop-Build $_ }

# Builds Noctty from source (github.com/amanthanvi/noctty) into Built\x64 and Built\ARM64, the way its release
# workflow does: scripts\build-package-windows.ps1 -Optimize ReleaseFast for each architecture (zig build, then
# package-windows.ps1, which adds the pinned ConPTY redistributable and makes the portable zip), and the portable
# zip's files are what goes into Built (not the Inno Setup installer; not code-signed).
# Needs: Zig (the version build.zig.zon asks for) and PowerShell 7 (this PC's pwsh, or a portable copy), both
# downloaded into the tools folder when missing
# Usage: build.cmd [-Version <x.y.z>] [-KeepWork] [-WorkDir <folder>]

$repo = 'amanthanvi/noctty'
$tag = if ($Version) { 'v' + ($Version -replace '^v') } else { Get-LatestGitHubTag $repo }
$ver = $tag -replace '^v'
$work = Start-Build -Name 'Noctty' -NeedGB 6
$src = Join-Path $work 'src'
# (some fuzzing test files have very long names: git's core.longpaths, set through the environment)
$env:GIT_CONFIG_COUNT = '1'; $env:GIT_CONFIG_KEY_0 = 'core.longpaths'; $env:GIT_CONFIG_VALUE_0 = 'true'
Get-GitSource "https://github.com/$repo.git" $tag $src -Submodules

# Zig: the version build.zig.zon names, from ziglang.org, into the tools folder
$zon = [IO.File]::ReadAllText((Join-Path $src 'build.zig.zon'))
$zigVersion = [regex]::Match($zon, '\.minimum_zig_version\s*=\s*"([^"]+)"').Groups[1].Value
if (-not $zigVersion) { throw "Couldn't find minimum_zig_version in build.zig.zon" }
$zigDir = Join-Path $script:toolsDir "zig-x86_64-windows-$zigVersion"
if (-not (Test-Path -LiteralPath (Join-Path $zigDir 'zig.exe'))) {
    Say "Getting Zig $zigVersion..."
    $zip = Join-Path $script:toolsDir "zig-x86_64-windows-$zigVersion.zip"
    Get-File "https://ziglang.org/download/$zigVersion/zig-x86_64-windows-$zigVersion.zip" $zip
    [IO.Compression.ZipFile]::ExtractToDirectory($zip, $script:toolsDir); Remove-Item -LiteralPath $zip
}
Add-ToPath $zigDir
# (Zig's package cache: the tools folder, unless ZIG_GLOBAL_CACHE_DIR names another)
if (-not $env:ZIG_GLOBAL_CACHE_DIR) { $env:ZIG_GLOBAL_CACHE_DIR = Join-Path $script:toolsDir 'zig-cache' }

# PowerShell 7 (the project's scripts are written for it): this PC's, or a portable one in the tools folder
$pwsh = Get-Command pwsh.exe -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty Source
if (-not $pwsh) {
    $pwsh = Join-Path $script:toolsDir 'pwsh\pwsh.exe'
    if (-not (Test-Path -LiteralPath $pwsh)) {
        Say 'Getting a portable PowerShell 7...'
        $release = Get-Text 'https://api.github.com/repos/PowerShell/PowerShell/releases/latest' | ConvertFrom-Json
        $asset = $release.assets | Where-Object { $_.name -match '^PowerShell-[\d.]+-win-x64\.zip$' } | Select-Object -First 1
        if (-not $asset) { throw "Couldn't find PowerShell's win-x64 zip in its latest release" }
        $zip = Join-Path $script:toolsDir $asset.name
        Get-File $asset.browser_download_url $zip
        [IO.Compression.ZipFile]::ExtractToDirectory($zip, (Join-Path $script:toolsDir 'pwsh')); Remove-Item -LiteralPath $zip
    }
}
# (PSModulePath is cleared by build.cmd for Windows PowerShell; pwsh finds its own modules again)

foreach ($arch in @(@{ Name = 'x64'; Folder = 'x64' }, @{ Name = 'arm64'; Folder = 'ARM64' })) {
    Say "Building Noctty for $($arch.Folder) (zig build -Doptimize=ReleaseFast)..."
    Invoke-Checked $pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $src 'scripts\build-package-windows.ps1') -Version $ver -Architecture $arch.Name -Optimize ReleaseFast
    $zip = Join-Path $src "dist\artifacts\noctty-$ver-windows-$($arch.Name)\noctty-$ver-windows-$($arch.Name)-portable.zip"
    if (-not (Test-Path -LiteralPath $zip)) { throw "The build didn't make $zip" }
    $out = Join-Path $work "out\$($arch.Folder)"
    [IO.Compression.ZipFile]::ExtractToDirectory($zip, $out)
    # (like update.cmd's -Flatten: the files, not a single folder they're in)
    $inner = @(Get-ChildItem -LiteralPath $out)
    if ($inner.Count -eq 1 -and $inner[0].PSIsContainer) { $out = $inner[0].FullName }
    Publish-Build -From $out -Arch $arch.Folder -Version $ver -Note "Source: https://github.com/$repo, tag $tag"
}
Complete-Build
