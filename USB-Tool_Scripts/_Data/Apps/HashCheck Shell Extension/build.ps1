param([string]$Version, [string]$WorkDir, [switch]$KeepWork, [switch]$Yes)
. "$PSScriptRoot\..\_Build-App.ps1"
trap { Stop-Build $_ }

# Builds the HashCheck Shell Extension from source (github.com/idrassi/HashCheck) into Built\x64 and Built\x86, the
# way its AppVeyor build makes the release versions (msbuild HashCheck.sln, Release|Win32 and Release|x64; only the
# HashCheck and HashCheckPackageHost projects, not the C# unit tests)
# Each folder has HashCheck.dll (with tbb12.dll for x64) and HashCheckPackageHost.exe: the files the official
# installer (HashCheckSetup, NSIS) puts in Program Files. Not built: the installer itself and its Windows 11 context
# menu package (HashCheckWin11.msix). To use the build, register the DLL from an elevated prompt with
# "regsvr32 HashCheck.dll" (and "regsvr32 /u HashCheck.dll" to remove it)
# Differences: built with Visual Studio 2022's toolset (v143) instead of the project's VS 2019 one (v142)
# Needs: Visual Studio 2022 with the C++ tools
# Usage: build.cmd [-Version <x.y.z>] [-KeepWork] [-WorkDir <folder>]

$repo = 'idrassi/HashCheck'
$tag = if ($Version) { 'v' + ($Version -replace '^v') } else { Get-LatestGitHubTag $repo }
$work = Start-Build -Name 'HashCheck Shell Extension' -NeedGB 1
$src = Join-Path $work 'src'
Get-GitSource "https://github.com/$repo.git" $tag $src

Use-VisualStudio -Arch x64 -Version '[17.0,18.0)' | Out-Null
foreach ($arch in @(@{ Platform = 'x64'; Folder = 'x64' }, @{ Platform = 'Win32'; Folder = 'x86' })) {
    Say "Building HashCheck $tag for $($arch.Folder)..."
    Invoke-Checked msbuild (Join-Path $src 'HashCheck.sln') /t:HashCheck /t:HashCheckPackageHost /m:4 /nologo /v:minimal /p:Configuration=Release "/p:Platform=$($arch.Platform)" /p:PlatformToolset=v143
    $bin = Join-Path $src "Bin\$($arch.Platform)\Release"
    $out = Join-Path $work "out\$($arch.Folder)"
    New-Item -ItemType Directory -Path $out -Force | Out-Null
    foreach ($f in 'HashCheck.dll', 'HashCheckPackageHost.exe', 'tbb12.dll') { if (Test-Path -LiteralPath (Join-Path $bin $f)) { Copy-Item -LiteralPath (Join-Path $bin $f) -Destination $out } }
    if (-not (Test-Path -LiteralPath (Join-Path $out 'HashCheck.dll'))) { throw "The build didn't make HashCheck.dll for $($arch.Folder)" }
    Copy-Item -LiteralPath (Join-Path $src 'license.txt') -Destination $out
    if (Test-Path -LiteralPath (Join-Path $out 'tbb12.dll')) { Copy-Item -LiteralPath (Join-Path $src 'libs\oneTBB\LICENSE.txt') -Destination (Join-Path $out 'tbb12-LICENSE.txt') }
    Publish-Build -From $out -Arch $arch.Folder -Version ($tag -replace '^v') -Note "Source: https://github.com/$repo, tag $tag (register with: regsvr32 HashCheck.dll, as admin)"
}
Complete-Build
