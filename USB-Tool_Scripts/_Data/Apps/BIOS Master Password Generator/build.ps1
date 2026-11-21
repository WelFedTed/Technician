param([string]$Version, [string]$WorkDir, [switch]$KeepWork, [switch]$Yes)
. "$PSScriptRoot\..\_Build-App.ps1"
trap { Stop-Build $_ }

# Builds the BIOS Master Password Generator (the bios-pw.org web page) from source (github.com/bacher09/pwgen-for-bios)
# into Built\Any, the way its deploy workflow builds the site (npm ci, then webpack in production mode): index.html,
# favicon.ico and assets\ (the TypeScript bundle, bootstrap.min.css, images), the same files update.cmd saves from
# bios-pw.org. (Built without the site's Google Analytics tag, since it's for offline use.)
# It's TypeScript, not Python, and has no releases: it builds the main branch (-Version takes another branch or tag).
# Needs: Node.js (this PC's, or a portable copy is downloaded) and Git
# Usage: build.cmd [-Version <branch or tag>] [-KeepWork] [-WorkDir <folder>]

$repo = 'bacher09/pwgen-for-bios'
$ref = if ($Version) { $Version } else { (Get-Text "https://api.github.com/repos/$repo" | ConvertFrom-Json).default_branch }
$work = Start-Build -Name 'BIOS Master Password Generator' -NeedGB 1
$src = Join-Path $work 'src'
Get-GitSource "https://github.com/$repo.git" $ref $src
$git = Get-Git
$commit = (& $git -C $src rev-parse --short=8 HEAD).Trim()
# (webpack's VersionInfoPlugin runs "git describe" itself)
Add-ToPath (Split-Path -Parent $git)

Use-Tool node
Push-Location -LiteralPath $src
try {
    Say 'Installing the build tools (npm ci)...'
    Invoke-Checked npm.cmd ci --no-audit --no-fund
    Say 'Building the page (webpack, production)...'
    $env:PRODUCTION = '1'; $env:GOOGLE_ANALYTICS_TAG = ''
    Invoke-Checked npx.cmd --no-install webpack
}
finally { Pop-Location }

# (bundle.<hash>.js: update.cmd's version is the first 8 characters of that hash)
$bundle = Get-ChildItem -LiteralPath (Join-Path $src 'dist\assets') -Filter 'bundle.*.js' | Select-Object -First 1
if (-not $bundle) { throw "webpack didn't make dist\assets\bundle.*.js" }
$hash = [regex]::Match($bundle.Name, 'bundle\.([0-9a-f]{8})').Groups[1].Value
# (the page doesn't need the source map; version-info.txt says what was built)
Get-ChildItem -LiteralPath (Join-Path $src 'dist') -Recurse -Filter '*.map' | Remove-Item -Force
Publish-Build -From (Join-Path $src 'dist') -Arch 'Any' -Version "$commit (bundle $hash)" -Note "Source: https://github.com/$repo, $ref at $commit"
Complete-Build
