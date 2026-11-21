param([string]$Version, [string]$WorkDir, [switch]$KeepWork, [switch]$Yes)
. "$PSScriptRoot\..\_Build-App.ps1"
trap { Stop-Build $_ }

# Builds WinDirStat from source (github.com/windirstat/windirstat) into Built\x64, Built\x86 and Built\ARM64, the way
# its build.cmd does a production release: msbuild windirstat.sln, Release, PRODUCTION=1 (WinDirStat.exe, as in the
# official WinDirStat.zip)
# The project uses Visual Studio 2026's toolset (v145) and ATL: Visual Studio 2026 is used when it has those,
# otherwise Visual Studio 2022 with its toolset (v143)
# ARM64 is built only when Visual Studio has its ARM64 C++ tools and ARM64 ATL
# Needs: Visual Studio 2026 or 2022 with the C++ tools and ATL (Microsoft.VisualStudio.Component.VC.ATL)
# Usage: build.cmd [-Version <x.y.z>] [-KeepWork] [-WorkDir <folder>]

$repo = 'windirstat/windirstat'
$tag = if ($Version) { 'release/v' + ($Version -replace '^(release/)?v') } else { Get-LatestGitHubTag $repo }
$ver = $tag -replace '^release/v'
$work = Start-Build -Name 'WinDirStat' -NeedGB 2
$src = Join-Path $work 'src'
Get-GitSource "https://github.com/$repo.git" $tag $src
# (the exe's build number is the Git commit count, which a shallow clone gives as 1: the history's commits are fetched,
# without their files)
Invoke-Checked (Get-Git) -C $src fetch -q --unshallow --filter=blob:none origin

function Test-VSComponent([string[]]$Components, [string]$Range = $vsRange) {
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    return [bool](& $vswhere -version $Range -products * -requires $Components -property installationPath)
}
$needs = @('Microsoft.VisualStudio.Component.VC.Tools.x86.x64', 'Microsoft.VisualStudio.Component.VC.ATL')
$vsRange = '[18.0,19.0)'; $toolset = @()
if (-not (Test-VSComponent $needs)) { $vsRange = '[17.0,18.0)'; $toolset = @('/p:PlatformToolset=v143') }
Use-VisualStudio -Arch x64 -Version $vsRange -Components $needs | Out-Null
foreach ($arch in @(@{ Platform = 'x64'; Folder = 'x64'; Short = 'x64' }, @{ Platform = 'Win32'; Folder = 'x86'; Short = 'x86' }, @{ Platform = 'ARM64'; Folder = 'ARM64'; Short = 'arm64'; Needs = @('Microsoft.VisualStudio.Component.VC.Tools.ARM64', 'Microsoft.VisualStudio.Component.VC.ATL.ARM64') })) {
    if ($arch.Needs -and -not (Test-VSComponent $arch.Needs)) { Say "Skipping $($arch.Folder): Visual Studio doesn't have $($arch.Needs -join ', ')"; continue }
    Say "Building WinDirStat $ver for $($arch.Folder)..."
    Invoke-Checked msbuild (Join-Path $src 'windirstat.sln') /m:2 /p:CL_MPCount=2 /nologo /v:minimal /p:Configuration=Release "/p:Platform=$($arch.Platform)" /p:Production=1 /p:ExternalCompilerOptions=/DPRODUCTION=1 @toolset
    $out = Join-Path $work "out\$($arch.Folder)"
    New-Item -ItemType Directory -Path $out -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $src "build\WinDirStat_$($arch.Short).exe") -Destination (Join-Path $out 'WinDirStat.exe')
    Publish-Build -From $out -Arch $arch.Folder -Version $ver -Note "Source: https://github.com/$repo, tag $tag"
}
Complete-Build
