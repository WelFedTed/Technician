param([string]$Version, [string]$WorkDir, [switch]$KeepWork, [switch]$Yes)
. "$PSScriptRoot\..\_Build-App.ps1"
trap { Stop-Build $_ }

# Builds AutoHotkey v2 from source (github.com/AutoHotkey/AutoHotkey) into Built\x86_x64: AutoHotkey32.exe and
# AutoHotkey64.exe, the two programs in the official zip, built with the project's own solution (AutoHotkeyx.sln,
# Release|Win32 and Release|x64). The zip's help file (AutoHotkeyDocs), dashboard scripts (AutoHotkeyUX) and
# WindowSpy are separate projects, so they aren't included.
# Needs: Visual Studio 2022 with the C++ tools (MSVC v143 and the Windows SDK)
# Usage: build.cmd [-Version <2.x.y>] [-KeepWork] [-WorkDir <folder>]

$repo = 'AutoHotkey/AutoHotkey'
# (its v1.1 releases are on the same repo, so only v2 tags count)
$tag = if ($Version) { 'v' + ($Version -replace '^v') } else { Get-LatestGitHubTag $repo -Match '^v2\.' }
$work = Start-Build -Name 'AutoHotkey' -NeedGB 1
$src = Join-Path $work 'src'
Get-GitSource "https://github.com/$repo.git" $tag $src

Use-VisualStudio -Arch x64 -Version '[17.0,18.0)' -Components @('Microsoft.VisualStudio.Component.VC.Tools.x86.x64') | Out-Null
$out = Join-Path $work 'out'
New-Item -ItemType Directory -Path $out -Force | Out-Null
Push-Location -LiteralPath $src
try {
    foreach ($platform in 'Win32', 'x64') {
        Say "Building AutoHotkey ($platform)..."
        Invoke-Checked msbuild AutoHotkeyx.sln /t:Build /p:Configuration=Release /p:Platform=$platform /m:4 /nologo /v:minimal
    }
}
finally { Pop-Location }

foreach ($exe in 'AutoHotkey32.exe', 'AutoHotkey64.exe') {
    $built = Get-ChildItem -LiteralPath (Join-Path $src 'bin') -Recurse -Filter $exe -File | Select-Object -First 1
    if (-not $built) { throw "The build didn't make $exe" }
    Copy-Item -LiteralPath $built.FullName -Destination $out
}
Copy-Item -LiteralPath (Join-Path $src 'license.txt') -Destination $out
Publish-Build -From $out -Arch 'x86_x64' -Version ($tag -replace '^v') -Note "Source: https://github.com/$repo, tag $tag"
Complete-Build
