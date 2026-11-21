param([string]$Version, [string]$WorkDir, [switch]$KeepWork, [switch]$Yes)
. "$PSScriptRoot\..\_Build-App.ps1"
trap { Stop-Build $_ }

# Builds the MediaInfo command line tool from source (github.com/MediaArea/MediaInfo, with MediaInfoLib, ZenLib and
# MediaArea's zlib next to it) into Built\x64, Built\x86 and Built\ARM64, with its own release scripts:
# Release\Build_CLI_Windows.ps1 (msbuild Project\MSVC2022\MediaInfo.sln, MediaInfo-CLI, static runtime), then the
# files Release_CLI_Windows.ps1 puts in the official MediaInfo_CLI zip (MediaInfo.exe, Plugin, License, History,
# ReadMe, Contrib)
# Not built: the MediaInfo GUI (the official Windows GUI is made with Embarcadero C++Builder, a paid compiler), and
# LIBCURL.DLL, which the official CLI zip has for reading URLs (local files work without it)
# ARM64 is built only when Visual Studio has its ARM64 C++ tools (Microsoft.VisualStudio.Component.VC.Tools.ARM64)
# Needs: Visual Studio 2022 with the C++ tools
# Usage: build.cmd [-Version <yy.mm>] [-KeepWork] [-WorkDir <folder>]

$tag = if ($Version) { 'v' + ($Version -replace '^v') } else { Get-LatestGitHubTag 'MediaArea/MediaInfo' }
$ver = $tag -replace '^v'
$work = Start-Build -Name 'MediaInfo' -NeedGB 3
# (the folders sit side by side, as the projects expect: MediaInfo, MediaInfoLib, ZenLib, zlib)
Get-GitSource 'https://github.com/MediaArea/MediaInfo.git' $tag (Join-Path $work 'MediaInfo')
Get-GitSource 'https://github.com/MediaArea/MediaInfoLib.git' $tag (Join-Path $work 'MediaInfoLib')
# (ZenLib and zlib have no matching release tags: MediaInfo's CI uses their main branches, so this takes the last
# commit of each from before this MediaInfoLib release, which is what that release was built with)
$git = Get-Git
$released = (& $git -C (Join-Path $work 'MediaInfoLib') log -1 --format=%cI).Trim()
foreach ($dep in 'ZenLib', 'zlib') {
    $dir = Join-Path $work $dep
    Say "Getting $dep as of $released..."
    Invoke-Checked $git clone -q --filter=blob:none --no-checkout "https://github.com/MediaArea/$dep.git" $dir
    $commit = (& $git -C $dir rev-list -1 "--before=$released" HEAD).Trim()
    if (-not $commit) { throw "Couldn't find a $dep commit from before $released" }
    Invoke-Checked $git -C $dir -c advice.detachedHead=false checkout -q $commit
}
$src = Join-Path $work 'MediaInfo'

function Test-VSComponent([string[]]$Components) {
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    return [bool](& $vswhere -version '[17.0,18.0)' -products * -requires $Components -property installationPath)
}
Use-VisualStudio -Arch x64 -Version '[17.0,18.0)' | Out-Null

foreach ($arch in @(@{ Platform = 'x64'; Folder = 'x64' }, @{ Platform = 'Win32'; Folder = 'x86' }, @{ Platform = 'ARM64'; Folder = 'ARM64'; Needs = 'Microsoft.VisualStudio.Component.VC.Tools.ARM64' })) {
    if ($arch.Needs -and -not (Test-VSComponent $arch.Needs)) { Say "Skipping $($arch.Folder): Visual Studio 2022 doesn't have $($arch.Needs)"; continue }
    Say "Building MediaInfo $ver (command line) for $($arch.Folder)..."
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $src 'Release\Build_CLI_Windows.ps1') -arch $arch.Platform -msvc MSVC2022
    if ($LASTEXITCODE -ne 0) { throw "Build_CLI_Windows.ps1 -arch $($arch.Platform) failed (exit code $LASTEXITCODE)" }
    # (Release_CLI_Windows.ps1's files, without LIBCURL.DLL)
    $out = Join-Path $work "out\$($arch.Folder)"
    New-Item -ItemType Directory -Path (Join-Path $out 'Plugin\Custom'), (Join-Path $out 'Contrib') -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $src "Project\MSVC2022\$($arch.Platform)\Release\MediaInfo.exe") -Destination $out
    Copy-Item -Path (Join-Path $src 'Source\Resource\Plugin\Custom\*') -Destination (Join-Path $out 'Plugin\Custom')
    Copy-Item -LiteralPath (Join-Path $src 'License.html'), (Join-Path $src 'LICENSE') -Destination $out
    Copy-Item -LiteralPath (Join-Path $src 'History_CLI.txt') -Destination (Join-Path $out 'History.txt')
    Copy-Item -LiteralPath (Join-Path $src 'Release\ReadMe_CLI_Windows.txt') -Destination (Join-Path $out 'ReadMe.txt')
    Copy-Item -LiteralPath (Join-Path $src 'Contrib\CLI_Help.doc') -Destination (Join-Path $out 'Contrib')
    Publish-Build -From $out -Arch $arch.Folder -Version $ver -Note "Source: https://github.com/MediaArea/MediaInfo, tag $tag (the command line tool, without LIBCURL.DLL)"
}
Complete-Build
