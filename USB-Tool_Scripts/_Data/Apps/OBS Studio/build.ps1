param([string]$Version, [string]$WorkDir, [switch]$KeepWork, [switch]$Yes)
. "$PSScriptRoot\..\_Build-App.ps1"
trap { Stop-Build $_ }

# Builds OBS Studio from source (github.com/obsproject/obs-studio, with its submodules: obs-browser, obs-websocket,
# ...) into Built\x64 (and Built\ARM64), the way its CI's .github/scripts/Build-Windows.ps1 does: "cmake --preset
# windows-x64" (which downloads the prebuilt obs-deps, Qt 6 and CEF its buildspec names), "cmake --build" with
# RelWithDebInfo, then "cmake --install" - the same bin\64bit, data and obs-plugins folders as the portable zip.
# Differences: Visual Studio 2022's generator (the preset asks for Visual Studio 2026, whose Build Tools here have
# no C++); not signed; no .pdb files. ARM64 is built only when Visual Studio has its ARM64 C++ tools
# (Microsoft.VisualStudio.Component.VC.Tools.ARM64).
# Needs: Visual Studio 2022 with C++, ATL (Microsoft.VisualStudio.Component.VC.ATL) and a Windows 10/11 SDK (10.0.20348 or\r
# newer), CMake, Git; the build downloads
# OBS's own prebuilt dependencies
# Usage: build.cmd [-Version <x.y.z>] [-KeepWork] [-WorkDir <folder>]

$repo = 'obsproject/obs-studio'
$tag = if ($Version) { $Version } else { Get-LatestGitHubTag $repo }
$work = Start-Build -Name 'OBS Studio' -NeedGB 15
$src = Join-Path $work 'src'
$env:GIT_CONFIG_COUNT = '1'; $env:GIT_CONFIG_KEY_0 = 'core.longpaths'; $env:GIT_CONFIG_VALUE_0 = 'true'
$env:PATH = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer;$env:PATH"
# (Visual Studio with ATL is checked first, so a missing part is reported before the big download)
$atl = 'Microsoft.VisualStudio.Component.VC.Tools.x86.x64', 'Microsoft.VisualStudio.Component.VC.ATL'
if (-not (& vswhere.exe -version '[17.0,18.0)' -products * -requires $atl -property installationPath)) { Use-VisualStudio -Arch x64 -Version '[17.0,18.0)' -Components $atl | Out-Null }
Get-GitSource "https://github.com/$repo.git" $tag $src -Submodules
if (-not (Get-Command cmake.exe -ErrorAction SilentlyContinue)) { throw 'This build needs CMake (cmake.org) on the PATH' }
$env:MSBUILDDISABLENODEREUSE = '1'
# (OBS compiles with /MP; this caps it, with MSBuild's own /m:2, at about 4 compilers at once)
$env:_CL_ = '/MP2'

$env:PATH = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer;$env:PATH"
$cleanEnv = @{}; Get-ChildItem Env: | ForEach-Object { $cleanEnv[$_.Name] = $_.Value }
function Reset-Env { Get-ChildItem Env: | Where-Object { -not $cleanEnv.ContainsKey($_.Name) } | ForEach-Object { Remove-Item -LiteralPath "Env:$($_.Name)" }; foreach ($k in $cleanEnv.Keys) { Set-Item -LiteralPath "Env:$k" -Value $cleanEnv[$k] } }
function Test-VSComponent([string[]]$Components) {
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    return [bool](& $vswhere -version '[17.0,18.0)' -products * -requires $Components -property installationPath)
}

foreach ($arch in @(
        @{ Preset = 'x64'; VS = 'x64'; Folder = 'x64'; Bits = '64bit' },
        @{ Preset = 'arm64'; VS = 'arm64'; Folder = 'ARM64'; Bits = 'arm64'; Needs = 'Microsoft.VisualStudio.Component.VC.Tools.ARM64' })) {
    if ($arch.Needs -and -not (Test-VSComponent $arch.Needs)) { Say "Skipping $($arch.Folder): Visual Studio 2022 doesn't have $($arch.Needs)"; continue }
    Reset-Env
    # (ATL: win-dshow's virtual camera module uses atlcomcli.h)
    Use-VisualStudio -Arch $arch.VS -Version '[17.0,18.0)' -Components (@('Microsoft.VisualStudio.Component.VC.Tools.x86.x64', 'Microsoft.VisualStudio.Component.VC.ATL') + @($arch.Needs | Where-Object { $_ })) | Out-Null
    Say "Building OBS Studio $tag for $($arch.Folder)..."
    $build = Join-Path $src "build_$($arch.Preset)"
    $install = Join-Path $work "install-$($arch.Folder)"
    Push-Location -LiteralPath $src
    try {
        Invoke-Checked cmake --preset "windows-$($arch.Preset)" -G 'Visual Studio 17 2022'
        Invoke-Checked cmake --build --preset "windows-$($arch.Preset)" --config RelWithDebInfo --parallel 2 '--' '/consoleLoggerParameters:Summary' '/noLogo'
        Invoke-Checked cmake --install $build --prefix $install --config RelWithDebInfo
    }
    finally { Pop-Location }
    if (-not (Test-Path -LiteralPath (Join-Path $install "bin\$($arch.Bits)\obs64.exe"))) { throw "The build didn't make bin\$($arch.Bits)\obs64.exe" }
    Get-ChildItem -LiteralPath $install -Recurse -Filter '*.pdb' -File | Remove-Item
    Publish-Build -From $install -Arch $arch.Folder -Version $tag -Note "Source: https://github.com/$repo, tag $tag (preset windows-$($arch.Preset), Visual Studio 2022, RelWithDebInfo)"
}
Complete-Build
