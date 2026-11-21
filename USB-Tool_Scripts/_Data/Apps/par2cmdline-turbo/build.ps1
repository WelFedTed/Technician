param([string]$Version, [string]$WorkDir, [switch]$KeepWork, [switch]$Yes)
. "$PSScriptRoot\..\_Build-App.ps1"
trap { Stop-Build $_ }

# Builds par2cmdline-turbo from source (github.com/animetosho/par2cmdline-turbo) into Built\x64 and Built\ARM64 (the
# platforms of its releases), the way its release workflow does: msbuild par2cmdline.sln, Release: par2.exe
# The releases are compiled with clang-cl (PlatformToolset=ClangCL); that's used when Visual Studio 2022 has it
# (Microsoft.VisualStudio.Component.VC.Llvm.Clang + VC.Llvm.ClangToolset), otherwise Visual Studio's own compiler
# (v143), which makes a working but somewhat slower par2.exe
# ARM64 is built only when Visual Studio has its ARM64 C++ tools (Microsoft.VisualStudio.Component.VC.Tools.ARM64)
# Needs: Visual Studio 2022 with the C++ tools
# Usage: build.cmd [-Version <x.y.z>] [-KeepWork] [-WorkDir <folder>]

$repo = 'animetosho/par2cmdline-turbo'
$tag = if ($Version) { 'v' + ($Version -replace '^v') } else { Get-LatestGitHubTag $repo }
$work = Start-Build -Name 'par2cmdline-turbo' -NeedGB 1
$src = Join-Path $work 'src'
Get-GitSource "https://github.com/$repo.git" $tag $src

function Test-VSComponent([string[]]$Components) {
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    return [bool](& $vswhere -version '[17.0,18.0)' -products * -requires $Components -property installationPath)
}
$clang = Test-VSComponent @('Microsoft.VisualStudio.Component.VC.Llvm.Clang', 'Microsoft.VisualStudio.Component.VC.Llvm.ClangToolset')
$toolset = if ($clang) { 'ClangCL' } else { 'v143' }
if (-not $clang) { Say "Visual Studio 2022 doesn't have clang-cl (the releases' compiler), so this uses its own compiler (v143)" }

Use-VisualStudio -Arch x64 -Version '[17.0,18.0)' | Out-Null
foreach ($arch in @(@{ Platform = 'x64'; Folder = 'x64' }, @{ Platform = 'ARM64'; Folder = 'ARM64'; Needs = 'Microsoft.VisualStudio.Component.VC.Tools.ARM64' })) {
    if ($arch.Needs -and -not (Test-VSComponent $arch.Needs)) { Say "Skipping $($arch.Folder): Visual Studio 2022 doesn't have $($arch.Needs)"; continue }
    Say "Building par2cmdline-turbo $tag for $($arch.Folder) ($toolset)..."
    Invoke-Checked msbuild (Join-Path $src 'par2cmdline.sln') /m:4 /nologo /v:minimal /p:Configuration=Release "/p:Platform=$($arch.Platform)" "/p:PlatformToolset=$toolset"
    Publish-Build -From (Join-Path $src "$($arch.Platform)\Release\par2.exe") -Arch $arch.Folder -Version ($tag -replace '^v') -Note "Source: https://github.com/$repo, tag $tag; compiler: $toolset"
}
Complete-Build
