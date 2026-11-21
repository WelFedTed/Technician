param([string]$Version, [string]$WorkDir, [switch]$KeepWork, [switch]$Yes)
. "$PSScriptRoot\..\_Build-App.ps1"
trap { Stop-Build $_ }

# Builds TranslucentTB from source (github.com/TranslucentTB/TranslucentTB) into Built\x64 and Built\ARM64, the way
# its release pipeline (.azp\release.yml, templates\build.yml) does: version info from the tag, NuGet restore, vcpkg,
# msbuild TranslucentTB.slnx Release (BuildType=Release), then the portable zip's files (create-portable.ps1: the
# *.exe, *.dll, resources.pri and Assets from AppPackage\bin\<platform>\Release). The MSIX bundle isn't made.
# The project needs Visual Studio 2026 with the parts in its .vsconfig (C++ desktop and UWP tools, MSIX packaging)
# ARM64 is built only when Visual Studio has its ARM64 C++ (and ARM64 UWP C++) tools
# Needs: Visual Studio 2026 with Microsoft.VisualStudio.Component.VC.Tools.x86.x64,
#        Microsoft.VisualStudio.Component.Windows11SDK.26100, Microsoft.VisualStudio.ComponentGroup.UWP.VC and
#        Microsoft.VisualStudio.ComponentGroup.MSIX.Packaging and Microsoft.VisualStudio.Component.Roslyn.Compiler (for vcpkg's
#        msbuild support); vcpkg and nuget.exe (downloaded into the tools folder)
# Usage: build.cmd [-Version <yyyy.n>] [-KeepWork] [-WorkDir <folder>]

$repo = 'TranslucentTB/TranslucentTB'
$tag = if ($Version) { $Version -replace '^v' } else { Get-LatestGitHubTag $repo }
$work = Start-Build -Name 'TranslucentTB' -NeedGB 8
$src = Join-Path $work 'src'
Get-GitSource "https://github.com/$repo.git" $tag $src

# (update-version.ps1 and update-manifest.ps1 -BuildType Release: a release tag has no commits after it)
$git = Get-Git
$head = (& $git -C $src rev-parse --short=7 HEAD).Trim()
$info = Join-Path $src 'Common\appinfo.hpp'
[IO.File]::WriteAllText($info, [IO.File]::ReadAllText($info).Replace('1,0,0,1', "$($tag.Replace('.', ',')),0,0").Replace('1.0.0.1', "$tag.0.$head"))
$appx = Join-Path $src 'AppPackage\Package.appxmanifest'
$content = [IO.File]::ReadAllText($appx).Replace('1.0.0.0', "$tag.0.0").Replace('Identity Name="TranslucentTB"', 'Identity Name="28017CharlesMilette.TranslucentTB"').Replace('TranslucentTB (Dev)', 'TranslucentTB').Replace('ms-resource:PublisherDisplayName', 'Charles Milette').Replace('CN=TranslucentTB Open Source Developers', 'CN=04797BBC-C7BB-462F-9B66-331C81E27C0E')
[IO.File]::WriteAllText($appx, $content)

# vcpkg (for the projects' vcpkg.json), used by msbuild without "vcpkg integrate" (which changes the user's setup)
function Use-Vcpkg {
    $dir = Join-Path $script:toolsDir 'vcpkg'
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
$vcpkgMsbuild = @("/p:ForceImportBeforeCppProps=$vcpkg\scripts\buildsystems\msbuild\vcpkg.props", "/p:ForceImportAfterCppTargets=$vcpkg\scripts\buildsystems\msbuild\vcpkg.targets", '/p:VcpkgEnableManifest=true')

$nuget = Join-Path $script:toolsDir 'nuget\nuget.exe'
if (-not (Test-Path -LiteralPath $nuget)) { Say 'Getting nuget.exe...'; Get-File 'https://dist.nuget.org/win-x86-commandline/latest/nuget.exe' $nuget }

$vsRange = '[18.0,19.0)'
function Test-VSComponent([string[]]$Components) {
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    return [bool](& $vswhere -version $vsRange -products * -requires $Components -property installationPath)
}
Use-VisualStudio -Arch x64 -Version $vsRange -Components @('Microsoft.VisualStudio.Component.VC.Tools.x86.x64', 'Microsoft.VisualStudio.Component.Windows11SDK.26100', 'Microsoft.VisualStudio.ComponentGroup.UWP.VC', 'Microsoft.VisualStudio.ComponentGroup.MSIX.Packaging', 'Microsoft.VisualStudio.Component.Roslyn.Compiler') | Out-Null
$sln = Join-Path $src 'TranslucentTB.slnx'
# (from nuget.org, with NuGet's package cache in the tools folder instead of the user's profile)
$env:NUGET_PACKAGES = Join-Path $script:toolsDir 'nuget\packages'
Invoke-Checked $nuget restore $sln -NonInteractive -Source https://api.nuget.org/v3/index.json

foreach ($arch in @(@{ Platform = 'x64'; Folder = 'x64' }, @{ Platform = 'ARM64'; Folder = 'ARM64'; Needs = @('Microsoft.VisualStudio.Component.VC.Tools.ARM64', 'Microsoft.VisualStudio.Component.UWP.VC.ARM64') })) {
    if ($arch.Needs -and -not (Test-VSComponent $arch.Needs)) { Say "Skipping $($arch.Folder): Visual Studio doesn't have $($arch.Needs -join ', ')"; continue }
    Say "Building TranslucentTB $tag for $($arch.Folder)..."
    Invoke-Checked msbuild $sln /m:2 /p:CL_MPCount=2 /nologo /v:minimal /p:Configuration=Release "/p:Platform=$($arch.Platform)" /p:BuildType=Release @vcpkgMsbuild
    # (create-portable.ps1's files)
    $bin = Join-Path $src "AppPackage\bin\$($arch.Platform)\Release"
    $out = Join-Path $work "out\$($arch.Folder)"
    New-Item -ItemType Directory -Path $out -Force | Out-Null
    # (picked by name first: with -Recurse, Windows PowerShell's -Include would also filter what's inside Assets)
    Get-ChildItem -LiteralPath $bin | Where-Object { $_.Name -like '*.exe' -or $_.Name -like '*.dll' -or $_.Name -eq 'resources.pri' -or $_.Name -eq 'Assets' } |
        Copy-Item -Destination $out -Recurse
    Publish-Build -From $out -Arch $arch.Folder -Version $tag -Note "Source: https://github.com/$repo, tag $tag"
}
Complete-Build
