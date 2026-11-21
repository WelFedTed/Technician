param([string]$Version, [string]$WorkDir, [switch]$KeepWork, [switch]$Yes)
. "$PSScriptRoot\..\_Build-App.ps1"
trap { Stop-Build $_ }

# Builds balenaEtcher from source (github.com/balena-io/etcher) into Built\x64, the way its release workflow
# (.github/actions/test and publish) builds it on Windows: npm ci (install scripts one at a time), plus
# winusb-driver-generator, then electron-forge, which also builds the etcher-util helper with pkg. The portable
# zip is electron-forge's packaged app folder, which is what's built here (npm run package, not the installer).
# Not set: the release's SENTRY_TOKEN / AMPLITUDE_TOKEN (its crash reports and analytics) and code signing.
# Needs: Visual Studio 2022 with the C++ tools (the native modules); Node.js (the major version .nvmrc pins) and
# Python (node-gyp): portable copies are downloaded when this PC doesn't have them; Git's patch.exe (with
# Git for Windows), which etcher's own pkg setup runs when pkg's Node.js base binary isn't downloaded yet.
# etcher-util is pkg's prebuilt Node.js base binary (from github.com/yao-pkg/pkg-fetch's release, as pkg gets it)
# with etcher's code; building that Node.js from source instead would take hours and needs Clang.
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
# balenaEtcher
# ---------------------------------------------------------------------------------------------

$repo = 'balena-io/etcher'
$tag = if ($Version) { 'v' + ($Version -replace '^v') } else { Get-LatestGitHubTag $repo }
$work = Start-Build -Name 'balenaEtcher' -NeedGB 6
$src = Join-Path $work 'src'
Get-GitSource "https://github.com/$repo.git" $tag $src

Use-VisualStudio -Arch x64 -Version '[17.0,18.0)' -Components 'Microsoft.VisualStudio.Component.VC.Tools.x86.x64' | Out-Null
Use-Tool python
$env:npm_config_python = (Get-Command python.exe | Select-Object -First 1).Source
Use-NodeVersion (Get-Content -LiteralPath (Join-Path $src '.nvmrc') -TotalCount 1)
# (pkg's Node.js base binaries)
$env:PKG_CACHE_PATH = Join-Path $script:toolsDir 'pkg-cache'
# (forge.pkg-node.ts checks pkg's Node.js patches with patch.exe, from Git for Windows; at the end of the PATH, so
# its other Unix tools don't stand in for Windows' own)
$gitPatch = Join-Path (Split-Path -Parent (Split-Path -Parent (Get-Git))) 'usr\bin'
if (Test-Path -LiteralPath (Join-Path $gitPatch 'patch.exe')) { $env:PATH = "$env:PATH;$gitPatch" }

# (winusb-driver-generator's build runs the embedder.exe it just built from its own folder, which cmd won't when
# this is set)
Remove-Item Env:NoDefaultCurrentDirectoryInExePath -ErrorAction SilentlyContinue

Push-Location -LiteralPath $src
try {
    # (install scripts one at a time: parallel node-gyp builds fetching the same Node.js headers fail on Windows)
    $env:npm_config_foreground_scripts = 'true'
    Say ''
    Say 'Installing the Node.js packages...'
    Invoke-Checked npm.cmd ci
    Invoke-Checked npm.cmd i -D winusb-driver-generator

    # etcher-util's Node.js base binary: when the pkg-fetch that etcher installs doesn't know the hash of the
    # version forge.pkg-node.ts asks for (it then stops with "Binary hash does NOT match", and would otherwise
    # build Node.js from source, which takes hours and needs Clang), it's downloaded here from the same pkg-fetch
    # release, checked against that release's own .sha256sum, and given to pkg with PKG_NODE_PATH
    $pkgNodeTs = Join-Path $src 'forge.pkg-node.ts'
    $fetchDir = Join-Path $src 'node_modules\@yao-pkg\pkg-fetch'
    $m = if (Test-Path -LiteralPath $pkgNodeTs) { Select-String -LiteralPath $pkgNodeTs -Pattern "PKG_NODE_VERSION = '(v[\d.]+)'" | Select-Object -First 1 }
    if ($m -and (Test-Path -LiteralPath $fetchDir)) {
        $pkgNode = $m.Matches[0].Groups[1].Value
        $fetchTag = 'v' + ((Get-Content -LiteralPath (Join-Path $fetchDir 'package.json') -Raw | ConvertFrom-Json).version -replace '^(\d+\.\d+).*', '$1')
        $name = "node-$pkgNode-win-x64"
        $expected = Get-Content -LiteralPath (Join-Path $fetchDir 'lib-es5\expected-shas.json') -Raw | ConvertFrom-Json
        if (-not $expected.$name) {
            $bin = Join-Path $env:PKG_CACHE_PATH "$fetchTag\fetched-$pkgNode-win-x64"
            if (-not (Test-Path -LiteralPath $bin)) {
                Say "Getting pkg's Node.js $pkgNode base binary (pkg-fetch $fetchTag)..."
                $address = "https://github.com/yao-pkg/pkg-fetch/releases/download/$fetchTag/$name"
                $sha = ((Get-Text "$address.sha256sum").Trim() -split '\s+')[0]
                Get-File $address "$bin.download"
                if ((Get-FileHash -LiteralPath "$bin.download" -Algorithm SHA256).Hash -ne $sha) { Remove-Item -LiteralPath "$bin.download"; throw "$name from pkg-fetch $fetchTag doesn't match its .sha256sum" }
                Move-Item -LiteralPath "$bin.download" -Destination $bin
            }
            $env:PKG_NODE_PATH = $bin
        }
    }
    Say ''
    Say 'Building balenaEtcher...'
    $env:NODE_ENV = 'production'
    Invoke-Checked npm.cmd run package
}
finally { Pop-Location }

$out = Join-Path $src 'out\balenaEtcher-win32-x64'
if (-not (Test-Path -LiteralPath (Join-Path $out 'balenaEtcher.exe'))) { throw "The build didn't make $out\balenaEtcher.exe" }
if (-not (Test-Path -LiteralPath (Join-Path $out 'resources\etcher-util.exe'))) { throw "The build didn't make resources\etcher-util.exe" }
Publish-Build -From $out -Arch x64 -Version ($tag -replace '^v') -Note "Source: https://github.com/$repo, tag $tag"
Complete-Build