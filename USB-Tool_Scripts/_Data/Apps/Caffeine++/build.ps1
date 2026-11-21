param([string]$Version, [string]$WorkDir, [switch]$KeepWork, [switch]$Yes)
. "$PSScriptRoot\..\_Build-App.ps1"
trap { Stop-Build $_ }

# Builds Caffeine++ from source (github.com/XarisA/CaffeinePP) into Built\x86 (the platform of its release), with
# its Visual Studio solution (caffeine++.sln, Release|x86): caffeine++.exe
# Differences: built with Visual Studio 2022's toolset (v143) instead of the project's VS 2019 one (v142); like the
# official one, it needs the Visual C++ (x86) runtime installed
# Needs: Visual Studio 2022 with the C++ tools
# Usage: build.cmd [-Version <x.y.z>] [-KeepWork] [-WorkDir <folder>]

$repo = 'XarisA/CaffeinePP'
$tag = if ($Version) { 'v' + ($Version -replace '^v') } else { Get-LatestGitHubTag $repo }
$work = Start-Build -Name 'Caffeine++' -NeedGB 1
$src = Join-Path $work 'src'
Get-GitSource "https://github.com/$repo.git" $tag $src

Use-VisualStudio -Arch x86 -Version '[17.0,18.0)' | Out-Null
Say "Building Caffeine++ $tag for x86..."
Invoke-Checked msbuild (Join-Path $src 'caffeine++.sln') /m:4 /nologo /v:minimal /p:Configuration=Release /p:Platform=x86 /p:PlatformToolset=v143
$exe = Get-ChildItem -LiteralPath $src -Recurse -Filter 'caffeine++.exe' | Where-Object { $_.DirectoryName -match '\\Release$' } | Select-Object -First 1
if (-not $exe) { throw "The build didn't make caffeine++.exe" }
Publish-Build -From $exe.FullName -Arch x86 -Version ($tag -replace '^v') -Note "Source: https://github.com/$repo, tag $tag"
Complete-Build
