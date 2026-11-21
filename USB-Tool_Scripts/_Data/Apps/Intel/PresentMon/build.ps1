param([string]$Version, [string]$WorkDir, [switch]$KeepWork, [switch]$Yes)
. "$PSScriptRoot\..\..\_Build-App.ps1"
trap { Stop-Build $_ }

# Builds the PresentMon command line tool from source (github.com/GameTechDev/PresentMon) into Built\x64, as its
# BUILDING.md describes: msbuild PresentMon\ConsoleApplication.sln, Release|x64 (with vcpkg for its libraries):
# PresentMon-<version>-x64.exe, the same file as the official CLI download
# Not built: the Intel PresentMon app and service (the MSI): they need the Chromium Embedded Framework, Node.js, WiX 3
# and a trusted code-signing certificate installed on the PC
# Needs: Visual Studio 2022 with the C++ tools; vcpkg (a portable copy is downloaded into the tools folder)
# Usage: build.cmd [-Version <x.y.z>] [-KeepWork] [-WorkDir <folder>]

$repo = 'GameTechDev/PresentMon'
$tag = if ($Version) { 'v' + ($Version -replace '^v') } else { Get-LatestGitHubTag $repo }
$ver = $tag -replace '^v'
$work = Start-Build -Name 'PresentMon' -NeedGB 4
$src = Join-Path $work 'src'
Get-GitSource "https://github.com/$repo.git" $tag $src

# vcpkg (for the projects' vcpkg.json), used by msbuild without "vcpkg integrate" (which changes the user's setup)
function Use-Vcpkg {
    $dir = Join-Path $script:toolsDir 'vcpkg'
    $git = Get-Git
    if (-not (Test-Path -LiteralPath (Join-Path $dir 'vcpkg.exe'))) {
        Say 'Getting a portable vcpkg...'
        if (Test-Path -LiteralPath $dir) { Remove-Item -LiteralPath $dir -Recurse -Force }
        Invoke-Checked $git -c core.longpaths=true clone -q https://github.com/microsoft/vcpkg.git $dir
        Invoke-Checked (Join-Path $dir 'bootstrap-vcpkg.bat') -disableMetrics
    }
    else { & $git -c core.longpaths=true -C $dir pull -q 2>$null }
    $cache = Join-Path $script:toolsDir 'vcpkg-cache'
    New-Item -ItemType Directory -Path $cache -Force | Out-Null
    # (its binary cache and registry cache in the tools folder too, instead of the user's profile)
    $registries = Join-Path $script:toolsDir 'vcpkg-registries'
    New-Item -ItemType Directory -Path $registries -Force | Out-Null
    $env:VCPKG_ROOT = $dir; $env:VCPKG_DEFAULT_BINARY_CACHE = $cache; $env:X_VCPKG_REGISTRIES_CACHE = $registries; $env:VCPKG_DISABLE_METRICS = '1'
    return $dir
}
$vcpkg = Use-Vcpkg
$vcpkgMsbuild = @("/p:ForceImportBeforeCppProps=$vcpkg\scripts\buildsystems\msbuild\vcpkg.props", "/p:ForceImportAfterCppTargets=$vcpkg\scripts\buildsystems\msbuild\vcpkg.targets")

$vs = Use-VisualStudio -Arch x64 -Version '[17.0,18.0)'
# (vcpkg builds the libraries with the same Visual Studio, 4 jobs at a time)
$env:VCPKG_VISUAL_STUDIO_PATH = $vs; $env:VCPKG_MAX_CONCURRENCY = '4'
# (the libraries in CommonUtilities' vcpkg.json are installed first, so msbuild only uses them: vcpkg's own install
# step in msbuild needs Visual Studio's C# compiler, which a C++-only Visual Studio doesn't have)
# (vcpkg downloads its own CMake etc. into downloads\tools, where CMake's long file names can hit Windows' path limit
# when the tools folder's path is long: then they go in the work folder instead, which -WorkDir can make short)
if ($vcpkg.Length -gt 70) { $env:VCPKG_DOWNLOADS = Join-Path $work 'vd'; New-Item -ItemType Directory -Path $env:VCPKG_DOWNLOADS -Force | Out-Null }
$triplet = 'x64-windows-static'
$manifest = Join-Path $src 'IntelPresentMon\CommonUtilities'
# (its vcpkg-configuration.json pins the ports to a vcpkg commit in a "git" registry, which makes vcpkg fetch all of
# vcpkg's history again; the same commit as a "builtin" registry uses the vcpkg clone in the tools folder instead)
$config = Join-Path $manifest 'vcpkg-configuration.json'
$baseline = (Get-Content -LiteralPath $config -Raw | ConvertFrom-Json).'default-registry'.baseline
if ($baseline) {
    & (Get-Git) -C $vcpkg fetch -q origin $baseline 2>$null
    [IO.File]::WriteAllText($config, "{ `"default-registry`": { `"kind`": `"builtin`", `"baseline`": `"$baseline`" } }")
}
Say 'Getting the libraries with vcpkg...'
# (vcpkg's own git calls get long-path support, and its build trees and installed libraries go in the work folder,
# which -WorkDir can make short: Boost's headers have long paths)
$env:GIT_CONFIG_COUNT = '1'; $env:GIT_CONFIG_KEY_0 = 'core.longpaths'; $env:GIT_CONFIG_VALUE_0 = 'true'
Invoke-Checked (Join-Path $vcpkg 'vcpkg.exe') install "--triplet=$triplet" "--host-triplet=$triplet" "--x-manifest-root=$manifest" "--x-install-root=$work\vi" "--x-buildtrees-root=$work\vt" "--x-packages-root=$work\vp"
Say "Building PresentMon $ver (command line) for x64..."
Invoke-Checked msbuild (Join-Path $src 'PresentMon\ConsoleApplication.sln') /m:2 /p:CL_MPCount=2 /nologo /v:minimal /p:Configuration=Release /p:Platform=x64 @vcpkgMsbuild /p:VcpkgManifestInstall=false "/p:VcpkgInstalledDir=$work\vi\\"
Publish-Build -From (Join-Path $src "PresentMon\build\Release\PresentMon-$ver-x64.exe") -Arch x64 -Version $ver -Note "Source: https://github.com/$repo, tag $tag (the command line tool only)"
Complete-Build
