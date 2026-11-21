param([string]$Version, [string]$WorkDir, [switch]$KeepWork, [switch]$Yes)
. "$PSScriptRoot\..\_Build-App.ps1"
trap { Stop-Build $_ }

# Builds "Code - OSS" from source (github.com/microsoft/vscode) into Built\x64: the open source build of VS Code,
# NOT the branded Microsoft "Visual Studio Code" that update.cmd downloads (that one adds Microsoft's product.json,
# license, telemetry and marketplace settings, which aren't public). It's the equivalent of the portable zip,
# built the way the project's Windows pipeline does (build/azure-pipelines/win32: pnpm install --frozen-lockfile,
# then gulp vscode-win32-x64-min, which compiles, minifies and packages ..\VSCode-win32-x64); its exe is
# Code - OSS.exe (in "Code - OSS" portable mode, add a data folder beside it, as for the official zip).
# Needs: Visual Studio 2022 with the C++ tools and the Spectre-mitigated libraries (the native modules are built
# with Spectre mitigation); Node.js (the version .nvmrc pins), Python (node-gyp) and pnpm (the version
# package.json's packageManager names): portable copies are downloaded when needed. Building uses up to 8 GB of
# memory (gulp's --max-old-space-size) and about 20 GB of disk.
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

# ---------------------------------------------------------------------------------------------
# Code - OSS
# ---------------------------------------------------------------------------------------------

$repo = 'microsoft/vscode'
$tag = if ($Version) { $Version -replace '^v' } else { Get-LatestGitHubTag $repo }
$work = Start-Build -Name 'Code-OSS' -NeedGB 20
$src = Join-Path $work 'vscode'
# (git long paths: some of its test files' names are very long)
if (-not $env:GIT_CONFIG_COUNT) { $env:GIT_CONFIG_COUNT = '1'; $env:GIT_CONFIG_KEY_0 = 'core.longpaths'; $env:GIT_CONFIG_VALUE_0 = 'true' }
Get-GitSource "https://github.com/$repo.git" $tag $src

Use-Tool python
$env:npm_config_python = (Get-Command python.exe | Select-Object -First 1).Source
Use-NodeVersion (Get-Content -LiteralPath (Join-Path $src '.nvmrc') -TotalCount 1)

# pnpm (the version package.json's packageManager names), installed with npm into the tools folder
$packageJson = Get-Content -LiteralPath (Join-Path $src 'package.json') -Raw | ConvertFrom-Json
$pnpmVersion = if ("$($packageJson.packageManager)" -match '^pnpm@([\w.+-]+)') { $Matches[1] } else { 'latest' }
$pnpmDir = Join-Path $script:toolsDir "pnpm-$pnpmVersion"
if (-not (Test-Path -LiteralPath (Join-Path $pnpmDir 'pnpm.cmd'))) {
    Say "Getting pnpm $pnpmVersion..."
    Invoke-Checked npm.cmd install --global --prefix $pnpmDir "pnpm@$pnpmVersion"
}
Add-ToPath $pnpmDir
$env:npm_config_store_dir = Join-Path $script:toolsDir 'pnpm-store'
$env:COREPACK_ENABLE_STRICT = '0'

# (Visual Studio for the native modules, which are built with Spectre mitigation)
Use-VisualStudio -Arch x64 -Version '[17.0,18.0)' -Components 'Microsoft.VisualStudio.Component.VC.Tools.x86.x64', 'Microsoft.VisualStudio.Component.VC.Runtimes.x86.x64.Spectre' | Out-Null
$env:npm_config_arch = 'x64'
$env:VSCODE_ARCH = 'x64'
$env:ELECTRON_SKIP_BINARY_DOWNLOAD = '1'
$env:PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = '1'
Push-Location -LiteralPath $src
try {
    Say ''
    Say 'Installing the Node.js packages...'
    Invoke-Checked pnpm.cmd install --frozen-lockfile
    Say ''
    Say 'Building Code - OSS (this takes a long time)...'
    Invoke-Checked pnpm.cmd run gulp vscode-win32-x64-min
}
finally { Pop-Location }

$out = Join-Path $work 'VSCode-win32-x64'
if (-not (Test-Path -LiteralPath (Join-Path $out 'Code - OSS.exe'))) { throw "The build didn't make $out\Code - OSS.exe" }
Publish-Build -From $out -Arch x64 -Version $tag -Note "Source: https://github.com/$repo, tag $tag. This is Code - OSS (the open source build), not Microsoft's branded Visual Studio Code."
Complete-Build