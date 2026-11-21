param([string]$Version, [string]$WorkDir, [switch]$KeepWork, [switch]$Yes)
. "$PSScriptRoot\..\_Build-App.ps1"
trap { Stop-Build $_ }

# Builds Rufus from source (github.com/pbatard/rufus) into Built\x64, Built\x86 and Built\ARM64, the way its Visual
# Studio workflow (.github\workflows\vs2026.yml) builds the releases: msbuild rufus.sln, Release, for each platform
# Named like the official downloads: rufus-<version>p.exe (x64, the portable one: it keeps its settings in rufus.ini
# next to it), rufus-<version>_x86.exe and rufus-<version>_arm64.exe
# Differences: built with Visual Studio 2022's toolset (v143) unless Visual Studio 2026 has its C++ tools (the
# project's v145); not compressed with UPX like the official x64 / x86 ones (so they're bigger); not signed
# ARM64 is built only when Visual Studio has its ARM64 C++ tools (Microsoft.VisualStudio.Component.VC.Tools.ARM64)
# Needs: Visual Studio 2022 (or 2026) with the C++ tools
# Usage: build.cmd [-Version <x.y>] [-KeepWork] [-WorkDir <folder>]

$repo = 'pbatard/rufus'
$tag = if ($Version) { 'v' + ($Version -replace '^v') } else { Get-LatestGitHubTag $repo }
$ver = $tag -replace '^v'
$work = Start-Build -Name 'Rufus' -NeedGB 2
$src = Join-Path $work 'src'
Get-GitSource "https://github.com/$repo.git" $tag $src -Submodules

function Test-VSComponent([string[]]$Components, [string]$Range = $vsRange) {
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    return [bool](& $vswhere -version $Range -products * -requires $Components -property installationPath)
}
# (Visual Studio 2026 when it has the C++ tools, as the project expects, otherwise 2022 with its own toolset)
$vsRange = '[18.0,19.0)'; $toolset = @()
if (-not (Test-VSComponent 'Microsoft.VisualStudio.Component.VC.Tools.x86.x64')) { $vsRange = '[17.0,18.0)'; $toolset = @('/p:PlatformToolset=v143') }
Use-VisualStudio -Arch x64 -Version $vsRange | Out-Null

foreach ($arch in @(@{ Platform = 'x64'; Folder = 'x64'; Name = "rufus-${ver}p.exe" }, @{ Platform = 'x86'; Folder = 'x86'; Name = "rufus-${ver}_x86.exe" }, @{ Platform = 'arm64'; Folder = 'ARM64'; Name = "rufus-${ver}_arm64.exe"; Needs = 'Microsoft.VisualStudio.Component.VC.Tools.ARM64' })) {
    if ($arch.Needs -and -not (Test-VSComponent $arch.Needs)) { Say "Skipping $($arch.Folder): Visual Studio doesn't have $($arch.Needs)"; continue }
    Say "Building Rufus $ver for $($arch.Folder)..."
    Invoke-Checked msbuild (Join-Path $src 'rufus.sln') /m:2 /p:CL_MPCount=2 /nologo /v:minimal /p:Configuration=Release "/p:Platform=$($arch.Platform)" @toolset
    $out = Join-Path $work "out\$($arch.Folder)"
    New-Item -ItemType Directory -Path $out -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $src "$($arch.Platform)\Release\rufus.exe") -Destination (Join-Path $out $arch.Name)
    Publish-Build -From $out -Arch $arch.Folder -Version $ver -Note "Source: https://github.com/$repo, tag $tag"
}
Complete-Build
