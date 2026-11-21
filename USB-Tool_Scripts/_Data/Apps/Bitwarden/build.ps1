param([string]$Version, [string]$WorkDir, [switch]$KeepWork, [switch]$Yes)
. "$PSScriptRoot\..\_Build-App.ps1"
trap { Stop-Build $_ }

# Builds the Bitwarden desktop app from source (github.com/bitwarden/clients, apps/desktop) into Built\x64, the
# way its release workflow (build-desktop.yml, windows) builds it: npm ci in the repo, the Rust native modules
# (desktop_native: node build.js --release), npm run build:oss (the open source build), then electron-builder's
# portable target (Bitwarden-Portable-<version>.exe, as in the release; not signed).
# Only x64: the release's portable exe holds x64, x86 and ARM64 builds, and the ARM64 Rust and native modules need
# Visual Studio's ARM64 C++ tools (Microsoft.VisualStudio.Component.VC.Tools.ARM64), which this PC doesn't have.
# Needs: Visual Studio 2022 with the C++ tools; Node.js (the major version .nvmrc pins), Python (node-gyp) and Rust
# (the version desktop_native's rust-toolchain.toml pins, with a portable rustup in the tools folder): portable
# copies are downloaded when needed. The source, node_modules and Rust build need about 15 GB.
# Usage: build.cmd [-Version <x.y.z>] [-KeepWork] [-WorkDir <folder>]
# ---------------------------------------------------------------------------------------------
# Node.js helper (the same in balenaEtcher's, GitHub Desktop's, Bitwarden's and VS Code's build.ps1)
# ---------------------------------------------------------------------------------------------

# the Node.js version a project pins (eg. '24' for the newest 24.x, or '24.22.1'): this PC's when it's that one,
# otherwise a portable copy from nodejs.org in the tools folder (in node-versions, apart from Use-Tool node's).
# Also keeps the npm / node-gyp / Electron download caches in the tools folder, not in the PC's user profile.
function Use-NodeVersion([string]$Wanted) {
    $Wanted = $Wanted.Trim() -replace '^v'
    $matchesWanted = { param($v) $v = $v -replace '^v'; $v -eq $Wanted -or $v -like "$Wanted.*" }
    $pc = Get-Command node.exe -ErrorAction SilentlyContinue | Select-Object -First 1
    $have = if ($pc) { (& $pc.Source --version 2>$null | Out-String).Trim() }
    if (-not ($have -and (& $matchesWanted $have))) {
        $base = Join-Path $script:toolsDir 'node-versions'
        # (ForEach-Object unrolls the JSON array, which Windows PowerShell 5.1 passes on as one object)
        $index = @(Get-Text 'https://nodejs.org/dist/index.json' | ConvertFrom-Json) | ForEach-Object { $_ }
        $release = $index | Where-Object { & $matchesWanted $_.version } | Select-Object -First 1
        if (-not $release) { throw "Couldn't find Node.js $Wanted on nodejs.org" }
        $dir = Join-Path $base "node-$($release.version)-win-x64"
        if (-not (Test-Path -LiteralPath "$dir\node.exe")) {
            Say "Getting a portable Node.js ($($release.version))..."
            $zip = Join-Path $base "node-$($release.version)-win-x64.zip"
            Get-File "https://nodejs.org/dist/$($release.version)/node-$($release.version)-win-x64.zip" $zip
            [IO.Compression.ZipFile]::ExtractToDirectory($zip, $base); Remove-Item -LiteralPath $zip
        }
        Add-ToPath $dir
        # (npm's global folder in it too, eg. for corepack's yarn)
        $env:npm_config_prefix = $dir
    }
    Say "Using Node.js $((& node --version | Out-String).Trim())"
    $env:npm_config_cache = Join-Path $script:toolsDir 'npm-cache'
    $env:npm_config_devdir = Join-Path $script:toolsDir 'node-gyp'
    $env:electron_config_cache = Join-Path $script:toolsDir 'electron-cache'
    $env:npm_config_update_notifier = 'false'
    $env:npm_config_fund = 'false'
    $env:npm_config_audit = 'false'
}

# a portable rustup in the tools folder (so the toolchain a project pins is downloaded there, not into the PC's
# own rustup); the project's rust-toolchain.toml then picks the toolchain
function Use-PortableRust {
    $env:RUSTUP_HOME = Join-Path $script:toolsDir 'rustup'; $env:CARGO_HOME = Join-Path $script:toolsDir 'cargo'
    if (-not (Test-Path -LiteralPath "$env:CARGO_HOME\bin\rustup.exe")) {
        Say 'Getting a portable Rust (rustup)...'
        $init = Join-Path $script:toolsDir 'rustup-init.exe'; Get-File 'https://static.rust-lang.org/rustup/dist/x86_64-pc-windows-msvc/rustup-init.exe' $init
        Invoke-Checked $init -y --no-modify-path --profile minimal --default-toolchain none
    }
    Add-ToPath "$env:CARGO_HOME\bin"
}

# ---------------------------------------------------------------------------------------------
# Bitwarden
# ---------------------------------------------------------------------------------------------

$repo = 'bitwarden/clients'
$tag = if ($Version) { 'desktop-v' + ($Version -replace '^(desktop-)?v?') } else { Get-LatestGitHubTag $repo -Match '^desktop-v' }
$version = $tag -replace '^desktop-v'
$work = Start-Build -Name 'Bitwarden' -NeedGB 15
$src = Join-Path $work 'src'
Get-GitSource "https://github.com/$repo.git" $tag $src
$desktop = Join-Path $src 'apps\desktop'

Use-VisualStudio -Arch x64 -Version '[17.0,18.0)' -Components 'Microsoft.VisualStudio.Component.VC.Tools.x86.x64' | Out-Null
Use-Tool python
$env:npm_config_python = (Get-Command python.exe | Select-Object -First 1).Source
Use-NodeVersion (Get-Content -LiteralPath (Join-Path $src '.nvmrc') -TotalCount 1)
$env:NODE_OPTIONS = '--max_old_space_size=4096'
$env:ELECTRON_BUILDER_CACHE = Join-Path $script:toolsDir 'electron-builder-cache'
Use-PortableRust

Push-Location -LiteralPath $src
try {
    Say ''
    Say 'Installing the Node.js packages...'
    Invoke-Checked npm.cmd ci
}
finally { Pop-Location }

Push-Location -LiteralPath (Join-Path $desktop 'desktop_native')
try {
    Say ''
    Say 'Building the Rust native modules...'
    Invoke-Checked rustup toolchain install
    Invoke-Checked node build.js --target=x86_64-pc-windows-msvc --release
}
finally { Pop-Location }

Push-Location -LiteralPath $desktop
try {
    Say ''
    Say 'Building Bitwarden...'
    Invoke-Checked npm.cmd run build:oss
    Invoke-Checked npm.cmd run clean:dist
    # (--publish, not -p, which PowerShell would take for Invoke-Checked's own parameter)
    Invoke-Checked npx.cmd electron-builder --win portable --x64 --publish never
}
finally { Pop-Location }

$exe = Join-Path $desktop "dist\Bitwarden-Portable-$version.exe"
if (-not (Test-Path -LiteralPath $exe)) { throw "The build didn't make $exe" }
Publish-Build -From $exe -Arch x64 -Version $version -Note "Source: https://github.com/$repo, tag $tag (apps/desktop, the open source build)"
Complete-Build