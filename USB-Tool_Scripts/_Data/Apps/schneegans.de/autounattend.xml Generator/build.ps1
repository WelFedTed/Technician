# Builds Christoph Schneegans' autounattend.xml generator library from source (github.com/cschneegans/unattend-generator)
# into Built\Any: UnattendGenerator.dll (the code behind https://schneegans.de/windows/unattend-generator/, which
# run.cmd opens) with Newtonsoft.Json.dll, and the project's Example.ps1, so answer files can be made offline from
# PowerShell 7.4 or newer (not Windows PowerShell 5.1): Import-Module ...\UnattendGenerator.dll, then see Example.ps1
# (The website itself isn't in the repository, and the project has no releases: this builds the master branch, the
# .NET 8 build of the library, the oldest of the ones it makes, which newer PowerShell 7 versions load too)
# Needs: the .NET SDK (this PC's, or a portable copy; 10.0, as the project's workflow uses)
# Usage: build.cmd [-Version <branch, tag or commit; default master>] [-KeepWork] [-WorkDir <folder>]
param([string]$Version, [string]$WorkDir, [switch]$KeepWork, [switch]$Yes)
. "$PSScriptRoot\..\..\_Build-App.ps1"
trap { Stop-Build $_ }

$repo = 'cschneegans/unattend-generator'
$ref = if ($Version) { $Version } else { 'master' }
$work = Start-Build -Name 'autounattend.xml Generator' -NeedGB 1
$src = Join-Path $work 'src'
$git = Get-Git
if ($ref -match '^[0-9a-f]{7,40}$') {
    # (a commit: the whole branch, then that commit)
    Say "Getting the source (commit $ref) from https://github.com/$repo.git..."
    Invoke-Checked $git clone --no-checkout "https://github.com/$repo.git" $src
    Push-Location -LiteralPath $src
    try { Invoke-Checked $git -c advice.detachedHead=false checkout -q $ref } finally { Pop-Location }
}
else { Get-GitSource "https://github.com/$repo.git" $ref $src }
Add-NuGetOrg $work
Push-Location -LiteralPath $src
try { $commit = "$(& $git log -1 --format='%h %cs')".Trim() } finally { Pop-Location }
$ver = 'master ' + $commit

Use-Tool dotnet -Version '10.0'
$env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'; $env:DOTNET_NOLOGO = '1'

# (only net8.0: its other targets include .NET versions newer than the SDK may know)
Say 'Building the library (net8.0)...'
$out = Join-Path $work 'out'
Invoke-Checked dotnet publish (Join-Path $src 'UnattendGenerator.csproj') --configuration Release /p:TargetFrameworks=net8.0 --framework net8.0 /m:4 --output $out
foreach ($f in 'Example.ps1', 'README.md', 'LICENSE.txt') { if (Test-Path -LiteralPath (Join-Path $src $f)) { Copy-Item -LiteralPath (Join-Path $src $f) -Destination $out } }
if (-not (Test-Path -LiteralPath (Join-Path $out 'UnattendGenerator.dll'))) { throw "The build didn't make UnattendGenerator.dll" }
Publish-Build -From $out -Arch 'Any' -Version $ver -Note "Source: https://github.com/$repo, $ref ($commit)"
Complete-Build
