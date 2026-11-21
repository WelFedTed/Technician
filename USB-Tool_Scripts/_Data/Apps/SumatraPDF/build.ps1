param([string]$Version, [string]$WorkDir, [switch]$KeepWork, [switch]$Yes)
. "$PSScriptRoot\..\_Build-App.ps1"
trap { Stop-Build $_ }

# Builds SumatraPDF from source (github.com/sumatrapdfreader/sumatrapdf) into Built\x64, Built\x86 and Built\ARM64,
# the way its release script (cmd\ci-build.ts) does: msbuild vs2022\SumatraPDF.sln, Release, target SumatraPDF:
# the single, portable SumatraPDF.exe (what the portable versions have; the installer is the same program)
# ARM64 is built only when Visual Studio has its ARM64 C++ tools (Microsoft.VisualStudio.Component.VC.Tools.ARM64)
# Needs: Visual Studio 2022 with the C++ tools (NASM comes with the source)
# Usage: build.cmd [-Version <x.y.z>] [-KeepWork] [-WorkDir <folder>]

$repo = 'sumatrapdfreader/sumatrapdf'
$tag = if ($Version) { ($Version -replace 'rel$') + 'rel' } else { Get-LatestGitHubTag $repo -Match 'rel$' }
$ver = $tag -replace 'rel$'
$work = Start-Build -Name 'SumatraPDF' -NeedGB 6
$src = Join-Path $work 'src'
# (some files in its ext folder have long paths)
$env:GIT_CONFIG_COUNT = '1'; $env:GIT_CONFIG_KEY_0 = 'core.longpaths'; $env:GIT_CONFIG_VALUE_0 = 'true'
Get-GitSource "https://github.com/$repo.git" $tag $src

function Test-VSComponent([string[]]$Components) {
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    return [bool](& $vswhere -version '[17.0,18.0)' -products * -requires $Components -property installationPath)
}

Use-VisualStudio -Arch x64 -Version '[17.0,18.0)' | Out-Null
foreach ($arch in @(@{ Platform = 'x64'; Out = 'rel64'; Folder = 'x64' }, @{ Platform = 'Win32'; Out = 'rel32'; Folder = 'x86' }, @{ Platform = 'ARM64'; Out = 'arm64'; Folder = 'ARM64'; Needs = 'Microsoft.VisualStudio.Component.VC.Tools.ARM64' })) {
    if ($arch.Needs -and -not (Test-VSComponent $arch.Needs)) { Say "Skipping $($arch.Folder): Visual Studio 2022 doesn't have $($arch.Needs)"; continue }
    Say "Building SumatraPDF $ver for $($arch.Folder)..."
    # (2 projects at a time, each compiling 2 files at a time)
    Invoke-Checked msbuild (Join-Path $src 'vs2022\SumatraPDF.sln') /t:SumatraPDF /m:2 /p:CL_MPCount=2 /nologo /v:minimal "/p:Configuration=Release;Platform=$($arch.Platform)"
    Publish-Build -From (Join-Path $src "out\$($arch.Out)\SumatraPDF.exe") -Arch $arch.Folder -Version $ver -Note "Source: https://github.com/$repo, tag $tag"
}
Complete-Build
