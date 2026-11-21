# Builds NAPS2 from source (github.com/cyanfish/naps2) into Built\x64, with the project's own build tool the way its
# portable zip is made (NAPS2.Tools "pkg zip": dotnet publish of NAPS2 (WinForms), NAPS2.Console and the 32-bit
# TWAIN worker, the portable launcher, then the zip's layout): NAPS2.Portable.exe, App\ and Data\
# Needs: the .NET 10 SDK (this PC's, or a portable copy)
# Usage: build.cmd [-Version <x.y.z>] [-KeepWork] [-WorkDir <folder>]
param([string]$Version, [string]$WorkDir, [switch]$KeepWork, [switch]$Yes)
. "$PSScriptRoot\..\_Build-App.ps1"
trap { Stop-Build $_ }
$repo = 'cyanfish/naps2'
$tag = if ($Version) { 'v' + ($Version -replace '^v') } else { Get-LatestGitHubTag $repo }
$work = Start-Build -Name 'NAPS2' -NeedGB 3
$src = Join-Path $work 'src'
Get-GitSource "https://github.com/$repo.git" $tag $src
Add-NuGetOrg $work

Use-Tool dotnet -Version '10.0'
$env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'; $env:DOTNET_NOLOGO = '1'

Say 'Building and packaging NAPS2 (NAPS2.Tools pkg zip)...'
Push-Location -LiteralPath $src
# ('--' quoted, or PowerShell takes it as its own end-of-parameters mark and doesn't pass it on)
try { Invoke-Checked dotnet run --project NAPS2.Tools '--' pkg zip --platform win64 --nosign -v }
finally { Pop-Location }

$zip = Get-ChildItem -LiteralPath (Join-Path $src 'NAPS2.Setup\publish') -Recurse -Filter 'naps2-*-win-x64.zip' | Select-Object -First 1
if (-not $zip) { throw "NAPS2.Tools made no zip in $(Join-Path $src 'NAPS2.Setup\publish')" }
$out = Join-Path $work 'portable'
Expand-Archive7 $zip.FullName $out
Publish-Build -From $out -Arch 'x64' -Version ($tag -replace '^v') -Note "Source: https://github.com/$repo, tag $tag (portable zip, unsigned)"
Complete-Build