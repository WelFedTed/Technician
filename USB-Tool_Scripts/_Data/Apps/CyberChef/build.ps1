param([string]$Version, [string]$WorkDir, [switch]$KeepWork, [switch]$Yes)
. "$PSScriptRoot\..\_Build-App.ps1"
trap { Stop-Build $_ }

# Builds CyberChef from source (github.com/gchq/CyberChef) into Built\Any, the way its release workflow does
# (npm ci, then npx grunt prod): the offline page CyberChef_v<version>.html with its assets, modules and images,
# the same files as the release zip.
# Needs: Node.js (the version the workflow and .nvmrc pin, 24; a portable copy is downloaded when this PC has
# another) and Git (this PC's, or a portable MinGit)
# Usage: build.cmd [-Version <x.y.z>] [-KeepWork] [-WorkDir <folder>]

$repo = 'gchq/CyberChef'
$tag = if ($Version) { 'v' + ($Version -replace '^v') } else { Get-LatestGitHubTag $repo }
$work = Start-Build -Name 'CyberChef' -NeedGB 3
$src = Join-Path $work 'src'
Get-GitSource "https://github.com/$repo.git" $tag $src

$nvmrc = Join-Path $src '.nvmrc'
Use-NodeVersion $(if (Test-Path -LiteralPath $nvmrc) { [IO.File]::ReadAllText($nvmrc) } else { '24' })
# (the workflow's "npm run setheapsize": webpack needs more memory than Node's default)
$env:NODE_OPTIONS = '--max_old_space_size=2048'

# (webpack.config.js's rules for the bitmap fonts and node_modules match "/" only, and webpack gives Windows paths
# with "\", so those rules are made to match either)
$config = Join-Path $src 'webpack.config.js'
$text = [IO.File]::ReadAllText($config)
$text = $text.Replace('bmfonts\/', 'bmfonts[\\/]').Replace('node_modules\/(?!', 'node_modules[\\/](?!')
[IO.File]::WriteAllText($config, $text)

Push-Location -LiteralPath $src
try {
    Say 'Installing the packages (npm ci)...'
    Invoke-Checked npm.cmd ci
    Say 'Building (grunt prod)...'
    Invoke-Checked npx.cmd grunt prod
}
finally { Pop-Location }

# (grunt prod makes the release zip, CyberChef_v<version>.zip, in build\prod: the offline page and its files)
$zip = Get-ChildItem -LiteralPath (Join-Path $src 'build\prod') -Filter 'CyberChef_v*.zip' | Select-Object -First 1
if (-not $zip) { throw "The build didn't make build\prod\CyberChef_v*.zip" }
$out = Join-Path $work 'out'
Expand-Archive7 $zip.FullName $out
if (-not (Get-ChildItem -LiteralPath $out -Filter 'CyberChef_v*.html')) { throw "The build's zip has no CyberChef_v*.html" }
Publish-Build -From $out -Arch 'Any' -Version ($tag -replace '^v') -Note "Source: https://github.com/$repo, tag $tag"
Complete-Build
