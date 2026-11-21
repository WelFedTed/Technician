param([string]$Version, [string]$WorkDir, [switch]$KeepWork, [switch]$Yes)
. "$PSScriptRoot\..\_Build-App.ps1"
trap { Stop-Build $_ }

# Builds GitHub Desktop from source (github.com/desktop/desktop) into Built\x64, the way its CI workflow (ci.yml,
# build) does on Windows: yarn (which also installs and builds the app's own packages), then yarn build:prod with
# RELEASE_CHANNEL=production, which makes the packaged app folder dist\GitHubDesktop-win32-x64 (the files the
# installer puts in %LOCALAPPDATA%\GitHubDesktop\app-<version>; yarn package, which only wraps that folder in the
# installers, isn't run).
# Not the same as the release: GitHub's OAuth app secrets (DESKTOP_OAUTH_CLIENT_ID / _SECRET) aren't public, so
# the build signs in with the project's development OAuth app; no error reporting endpoint; not code signed.
# Needs: Visual Studio 2022 with the C++ tools (native modules); Node.js (the exact version .nvmrc pins), Python
# (node-gyp) and Yarn 1: portable copies are downloaded when this PC doesn't have them.
# ARM64 isn't built: this PC's Visual Studio has no ARM64 C++ tools (VC.Tools.ARM64), which its native modules need.
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
# GitHub Desktop
# ---------------------------------------------------------------------------------------------

$repo = 'desktop/desktop'
$tag = if ($Version) { 'release-' + ($Version -replace '^(release-)?v?') } else { Get-LatestGitHubTag $repo }
$work = Start-Build -Name 'GitHub Desktop' -NeedGB 6
$src = Join-Path $work 'src'
Get-GitSource "https://github.com/$repo.git" $tag $src -Submodules

Use-VisualStudio -Arch x64 -Version '[17.0,18.0)' -Components 'Microsoft.VisualStudio.Component.VC.Tools.x86.x64' | Out-Null
Use-Tool python
$env:npm_config_python = (Get-Command python.exe | Select-Object -First 1).Source
Use-NodeVersion (Get-Content -LiteralPath (Join-Path $src '.nvmrc') -TotalCount 1)

# Yarn 1 (this PC's, or one installed with npm into the tools folder)
$yarn = Get-Command yarn -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $yarn -or ((& $yarn.Source --version 2>$null | Out-String).Trim() -notmatch '^1\.')) {
    $yarnDir = Join-Path $script:toolsDir 'yarn-classic'
    if (-not (Test-Path -LiteralPath (Join-Path $yarnDir 'yarn.cmd'))) {
        Say 'Getting Yarn 1...'
        Invoke-Checked npm.cmd install --global --prefix $yarnDir 'yarn@1'
    }
    Add-ToPath $yarnDir
}
$env:YARN_CACHE_FOLDER = Join-Path $script:toolsDir 'yarn-cache'
# (the install's last step gets Playwright's ffmpeg, for the project's tests: kept in the tools folder too)
$env:PLAYWRIGHT_BROWSERS_PATH = Join-Path $script:toolsDir 'ms-playwright'
# (and it runs git for the submodules)
Add-ToPath (Split-Path -Parent (Get-Git))

$env:RELEASE_CHANNEL = 'production'
$env:npm_config_arch = 'x64'
$env:TARGET_ARCH = 'x64'
Push-Location -LiteralPath $src
try {
    Say ''
    Say 'Installing the Node.js packages...'
    Invoke-Checked yarn.cmd --frozen-lockfile --network-timeout 600000
    Say ''
    Say 'Building GitHub Desktop...'
    Invoke-Checked yarn.cmd build:prod
}
finally { Pop-Location }

$out = Join-Path $src 'dist\GitHubDesktop-win32-x64'
if (-not (Test-Path -LiteralPath (Join-Path $out 'GitHubDesktop.exe'))) { throw "The build didn't make $out\GitHubDesktop.exe" }
Publish-Build -From $out -Arch x64 -Version ($tag -replace '^release-') -Note "Source: https://github.com/$repo, tag $tag. Start GitHubDesktop.exe in this folder (the installer's Squirrel launcher isn't part of it)."
Complete-Build