param([string]$Version, [string]$WorkDir, [switch]$KeepWork, [switch]$Yes)
. "$PSScriptRoot\..\_Build-App.ps1"
trap { Stop-Build $_ }

# Builds Zed from source (github.com/zed-industries/zed) into Built\x64 (and Built\ARM64), the way its
# script\bundle-windows.ps1 builds a release (cargo --config .cargo/bundle-config.toml build --release of zed, cli,
# auto_update_helper and explorer_command_injector, plus the AMD AGS DLL and the ConPTY files it downloads, and the
# explorer integration's appx made with makeappx), laid out like the installed app: Zed.exe, bin\zed.exe, tools\,
# appx\, conpty.dll, x64\ and arm64\OpenConsole.exe, amd_ags_x64.dll (x64 only). Not made: the Inno Setup installer,
# the code signing. ARM64 is built only when Visual Studio has its ARM64 C++ tools and Spectre-mitigated libraries.
# It's a very large Rust build (an hour or more for each architecture, ~30 GB).
# Needs: Rust (rustup), CMake, and Visual Studio 2022 with the C++ tools, the Spectre-mitigated libraries and a
# Windows 11 SDK (as docs\src\development\windows.md says)
# Usage: build.cmd [-Version <x.y.z>] [-KeepWork] [-WorkDir <folder>]

$repo = 'zed-industries/zed'
$tag = if ($Version) { 'v' + ($Version -replace '^v') } else { Get-LatestGitHubTag $repo }
$work = Start-Build -Name 'Zed' -NeedGB 40
$src = Join-Path $work 'src'
Get-GitSource "https://github.com/$repo.git" $tag $src

$vsBase = @('Microsoft.VisualStudio.Component.VC.Tools.x86.x64', 'Microsoft.VisualStudio.Component.VC.Runtimes.x86.x64.Spectre', 'Microsoft.VisualStudio.Component.Windows11SDK.26100')
# (checked first, so a missing part is reported before the long build)
Use-VisualStudio -Arch x64 -Version '[17.0,18.0)' -Components $vsBase | Out-Null
if (-not (Get-Command cmake.exe -ErrorAction SilentlyContinue)) { throw 'Zed needs CMake (cmake.org); none was found' }
Use-Tool rust
$env:CARGO_BUILD_JOBS = '4'
$channel = ([IO.File]::ReadAllText((Join-Path $src 'crates\zed\RELEASE_CHANNEL'))).Trim()
$env:ZED_RELEASE_CHANNEL = $channel; $env:RELEASE_CHANNEL = $channel; $env:ZED_WORKSPACE = $src
$env:RELEASE_VERSION = $tag -replace '^v'

# the AMD GPU Services DLL and ConPTY, from the URLs bundle-windows.ps1 uses
$script = [IO.File]::ReadAllText((Join-Path $src 'script\bundle-windows.ps1'))
$agsUrl = [regex]::Match($script, 'https://codeload\.github\.com/GPUOpen-LibrariesAndSDKs/AGS_SDK/zip/refs/tags/v[\d.]+').Value
$conptyUrl = [regex]::Match($script, 'https://github\.com/microsoft/terminal/releases/download/[^"]+\.nupkg').Value
if (-not $agsUrl -or -not $conptyUrl) { throw "Couldn't find the AGS SDK or ConPTY downloads in script\bundle-windows.ps1" }
Get-File $agsUrl (Join-Path $work 'ags.zip'); Expand-Archive7 (Join-Path $work 'ags.zip') (Join-Path $work 'ags')
Get-File $conptyUrl (Join-Path $work 'conpty.zip'); Expand-Archive7 (Join-Path $work 'conpty.zip') (Join-Path $work 'conpty')
$ags = Get-ChildItem -LiteralPath (Join-Path $work 'ags') -Recurse -Filter 'amd_ags_x64.dll' | Where-Object { $_.Directory.Name -eq 'lib' } | Select-Object -First 1
$makeAppx = Get-ChildItem -Path "${env:ProgramFiles(x86)}\Windows Kits\10\bin\10.*\x64\makeappx.exe" -ErrorAction SilentlyContinue | Sort-Object FullName | Select-Object -Last 1
if (-not $makeAppx) { throw "The Windows SDK's makeappx.exe wasn't found" }

$cleanEnv = @{}; Get-ChildItem Env: | ForEach-Object { $cleanEnv[$_.Name] = $_.Value }
function Reset-Env { Get-ChildItem Env: | Where-Object { -not $cleanEnv.ContainsKey($_.Name) } | ForEach-Object { Remove-Item -LiteralPath "Env:$($_.Name)" }; foreach ($k in $cleanEnv.Keys) { Set-Item -LiteralPath "Env:$k" -Value $cleanEnv[$k] } }
function Test-VSComponent([string[]]$Components) {
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    return [bool](& $vswhere -version '[17.0,18.0)' -products * -requires $Components -property installationPath)
}

foreach ($arch in @(
        @{ Rust = 'x86_64'; VS = 'x64'; Folder = 'x64'; ConPty = 'x64' },
        @{ Rust = 'aarch64'; VS = 'arm64'; Folder = 'ARM64'; ConPty = 'arm64'; Needs = @('Microsoft.VisualStudio.Component.VC.Tools.ARM64', 'Microsoft.VisualStudio.Component.VC.Runtimes.ARM64.Spectre') })) {
    if ($arch.Needs -and -not (Test-VSComponent $arch.Needs)) { Say "Skipping $($arch.Folder): Visual Studio 2022 doesn't have $($arch.Needs -join ', ')"; continue }
    Reset-Env
    # (the target's build environment, as bundle-windows.ps1's Launch-VsDevShell -Arch, for the crates that compile C)
    Use-VisualStudio -Arch $arch.VS -Version '[17.0,18.0)' -Components ($vsBase + @($arch.Needs | Where-Object { $_ })) | Out-Null
    $target = "$($arch.Rust)-pc-windows-msvc"
    $out = Join-Path $work "out-$($arch.Folder)"
    foreach ($d in 'bin', 'tools', 'appx', 'arm64', 'make_appx') { New-Item -ItemType Directory -Path (Join-Path $out $d) -Force | Out-Null }
    Push-Location -LiteralPath $src
    try {
        # (the toolchain rust-toolchain.toml names, with this target)
        Invoke-Checked rustup target add $target
        Say "Building Zed $tag for $($arch.Folder) ($channel; this takes a long time)..."
        Invoke-Checked cargo --config .cargo/bundle-config.toml build --release --package zed --package cli --package auto_update_helper --target $target
        $features = switch ($channel) { 'stable' { @('--features', 'stable', '--no-default-features') } 'preview' { @('--features', 'preview', '--no-default-features') } default { @() } }
        Invoke-Checked cargo --config .cargo/bundle-config.toml build --release @features --package explorer_command_injector --target $target
    }
    finally { Pop-Location }
    $cargoOut = Join-Path $src "target\$target\release"
    Copy-Item -Path (Join-Path $src 'crates\zed\resources\windows\zed.sh') -Destination (Join-Path $out 'bin\zed')
    Copy-Item -LiteralPath (Join-Path $cargoOut 'zed.exe') -Destination (Join-Path $out 'Zed.exe')
    Copy-Item -LiteralPath (Join-Path $cargoOut 'cli.exe') -Destination (Join-Path $out 'bin\zed.exe')
    Copy-Item -LiteralPath (Join-Path $cargoOut 'auto-update-helper.exe') -Destination (Join-Path $out 'tools\auto_update_helper.exe')
    Copy-Item -LiteralPath (Join-Path $cargoOut 'explorer_command_injector.dll') -Destination (Join-Path $out 'appx\zed_explorer_command_injector.dll')

    # the explorer integration's appx (MakeAppx in bundle-windows.ps1)
    $manifest = switch ($channel) { 'stable' { 'AppxManifest.xml' } 'preview' { 'AppxManifest-Preview.xml' } default { 'AppxManifest-Nightly.xml' } }
    Copy-Item -LiteralPath (Join-Path $src "crates\explorer_command_injector\$manifest") -Destination (Join-Path $out 'make_appx\AppxManifest.xml')
    Invoke-Checked $makeAppx.FullName pack /d (Join-Path $out 'make_appx') /p (Join-Path $out 'appx\zed_explorer_command_injector.appx') /nv
    Remove-Item -LiteralPath (Join-Path $out 'make_appx') -Recurse -Force

    # (as CollectFiles: x64 gets AGS and both OpenConsole.exe; ARM64 only its own OpenConsole.exe)
    if ($arch.Folder -eq 'x64') {
        Copy-Item -LiteralPath $ags.FullName -Destination $out
        New-Item -ItemType Directory -Path (Join-Path $out 'x64') -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $work 'conpty\build\native\runtimes\x64\OpenConsole.exe') -Destination (Join-Path $out 'x64')
    }
    Copy-Item -LiteralPath (Join-Path $work 'conpty\build\native\runtimes\arm64\OpenConsole.exe') -Destination (Join-Path $out 'arm64')
    Copy-Item -LiteralPath (Join-Path $work "conpty\runtimes\win-$($arch.ConPty)\native\conpty.dll") -Destination $out

    Publish-Build -From $out -Arch $arch.Folder -Version ($tag -replace '^v') -Note "Source: https://github.com/$repo, tag $tag (target $target, channel $channel; not signed, no installer)"
}
Complete-Build
