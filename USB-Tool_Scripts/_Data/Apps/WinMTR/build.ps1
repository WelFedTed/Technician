param([string]$Version, [string]$WorkDir, [switch]$KeepWork, [switch]$Yes)
. "$PSScriptRoot\..\_Build-App.ps1"
trap { Stop-Build $_ }

# Builds WinMTR (WinMTR-refresh, github.com/leeter/WinMTR-refresh) from source into Built\x64 and Built\ARM64 (the
# platforms of its releases), with its Visual Studio solution (WinMTR.sln, Release: static MFC, cppwinrt from vcpkg)
# ARM64 is built only when Visual Studio has its ARM64 C++ tools and ARM64 MFC
# Needs: Visual Studio 2022 with the C++ tools, MFC (Microsoft.VisualStudio.Component.VC.ATLMFC) and the C# compiler
#        (Microsoft.VisualStudio.Component.Roslyn.Compiler, which vcpkg's msbuild support uses); vcpkg (a portable copy is
#        downloaded into the tools folder)
# Usage: build.cmd [-Version <x.yy>] [-KeepWork] [-WorkDir <folder>]

$repo = 'leeter/WinMTR-refresh'
$tag = if ($Version) { 'v' + ($Version -replace '^v') } else { Get-LatestGitHubTag $repo }
$work = Start-Build -Name 'WinMTR' -NeedGB 3
$src = Join-Path $work 'src'
Get-GitSource "https://github.com/$repo.git" $tag $src

# vcpkg (for the project's vcpkg.json), used by msbuild without "vcpkg integrate" (which changes the user's setup)
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
$vcpkgMsbuild = @("/p:ForceImportBeforeCppProps=$vcpkg\scripts\buildsystems\msbuild\vcpkg.props", "/p:ForceImportAfterCppTargets=$vcpkg\scripts\buildsystems\msbuild\vcpkg.targets", '/p:VcpkgEnableManifest=true')

# (each architecture starts from the same environment, since Use-VisualStudio adds to it)
$cleanEnv = @{}; Get-ChildItem Env: | ForEach-Object { $cleanEnv[$_.Name] = $_.Value }
function Reset-Env { Get-ChildItem Env: | Where-Object { -not $cleanEnv.ContainsKey($_.Name) } | ForEach-Object { Remove-Item -LiteralPath "Env:$($_.Name)" }; foreach ($k in $cleanEnv.Keys) { Set-Item -LiteralPath "Env:$k" -Value $cleanEnv[$k] } }
function Test-VSComponent([string[]]$Components) {
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    return [bool](& $vswhere -version '[17.0,18.0)' -products * -requires $Components -property installationPath)
}

foreach ($arch in @(@{ Platform = 'x64'; Folder = 'x64' }, @{ Platform = 'ARM64'; Folder = 'ARM64'; Needs = @('Microsoft.VisualStudio.Component.VC.Tools.ARM64', 'Microsoft.VisualStudio.Component.VC.MFC.ARM64') })) {
    if ($arch.Needs -and -not (Test-VSComponent $arch.Needs)) { Say "Skipping $($arch.Folder): Visual Studio 2022 doesn't have $($arch.Needs -join ', ')"; continue }
    Reset-Env
    $components = @('Microsoft.VisualStudio.Component.VC.Tools.x86.x64', 'Microsoft.VisualStudio.Component.VC.ATLMFC', 'Microsoft.VisualStudio.Component.Roslyn.Compiler') + @($arch.Needs | Where-Object { $_ })
    Use-VisualStudio -Arch x64 -Version '[17.0,18.0)' -Components $components | Out-Null
    Say "Building WinMTR $tag for $($arch.Folder)..."
    Invoke-Checked msbuild (Join-Path $src 'WinMTR.sln') /m:4 /nologo /v:minimal /p:Configuration=Release "/p:Platform=$($arch.Platform)" @vcpkgMsbuild
    $out = Join-Path $work "out\$($arch.Folder)"
    New-Item -ItemType Directory -Path $out -Force | Out-Null
    $exe = Get-ChildItem -LiteralPath $src -Recurse -Filter 'WinMTR.exe' | Where-Object { $_.DirectoryName -like "*Release_$($arch.Platform)*" } | Select-Object -First 1
    if (-not $exe) { throw "The build didn't make WinMTR.exe for $($arch.Folder)" }
    Copy-Item -LiteralPath $exe.FullName -Destination $out
    Publish-Build -From $out -Arch $arch.Folder -Version ($tag -replace '^v') -Note "Source: https://github.com/$repo, tag $tag"
}
Complete-Build
