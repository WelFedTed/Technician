# Builds ShareX from source (github.com/ShareX/ShareX) into Built\x64, the way its release workflow makes the portable
# version (.github\workflows\build.yml: dotnet build + publish of the self-contained Release x64 build, FFmpeg from
# BtbN's FFmpeg-Builds, then ShareX.Setup's CreatePortable job): ShareX.exe with the .NET runtime, ffmpeg.exe, the
# Languages and Licenses folders and the "Portable" marker file
# (Uploaders that need the API keys from ShareX's GitHub secrets have none in this build)
# Needs: the .NET 10 SDK (this PC's, or a portable copy)
# Usage: build.cmd [-Version <x.y.z>] [-KeepWork] [-WorkDir <folder>]
param([string]$Version, [string]$WorkDir, [switch]$KeepWork, [switch]$Yes)
. "$PSScriptRoot\..\_Build-App.ps1"
trap { Stop-Build $_ }

$repo = 'ShareX/ShareX'
$tag = if ($Version) { 'v' + ($Version -replace '^v') } else { Get-LatestGitHubTag $repo }
$work = Start-Build -Name 'ShareX' -NeedGB 3
$src = Join-Path $work 'src'
Get-GitSource "https://github.com/$repo.git" $tag $src
Add-NuGetOrg $work

Use-Tool dotnet -Version '10.0'
$env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'; $env:DOTNET_NOLOGO = '1'

# (the workflow's "Disable Dev flag" step, done for release tags)
$appInfo = Join-Path $src 'ShareX\Infrastructure\ApplicationInfo.cs'
$text = [IO.File]::ReadAllText($appInfo)
if ($text -notmatch 'internal const bool Dev = (true|false);') { throw "The Dev flag wasn't found in $appInfo" }
[IO.File]::WriteAllText($appInfo, ($text -replace 'internal const bool Dev = (true|false);', 'internal const bool Dev = false;'), (New-Object Text.UTF8Encoding($false)))

$sln = Join-Path $src 'ShareX.sln'
$bin = Join-Path $src 'ShareX\bin\Release\win-x64'
Say 'Restoring the packages...'
Invoke-Checked dotnet restore --runtime win-x64 $sln
Say 'Building ShareX...'
Invoke-Checked dotnet build --no-restore --configuration Release /p:Platform=x64 --self-contained true /m:4 $sln
Invoke-Checked dotnet publish --no-build --configuration Release /p:Platform=x64 --self-contained true -o $bin (Join-Path $src 'ShareX\ShareX.csproj')

# (the FFmpeg the workflow puts next to ShareX.exe: its FFMPEG_VERSION, from BtbN's builds)
$ffmpegVersion = '9.0'
$workflow = Join-Path $src '.github\workflows\build.yml'
if (Test-Path -LiteralPath $workflow) {
    $m = Select-String -LiteralPath $workflow -Pattern 'FFMPEG_VERSION:\s*"?([\d.]+)' | Select-Object -First 1
    if ($m) { $ffmpegVersion = $m.Matches[0].Groups[1].Value }
}
Say "Getting FFmpeg $ffmpegVersion (BtbN's FFmpeg-Builds)..."
$ffZip = Join-Path $work 'ffmpeg.zip'
Get-File "https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-n$ffmpegVersion-latest-win64-gpl-$ffmpegVersion.zip" $ffZip
Expand-Archive7 $ffZip (Join-Path $work 'ffmpeg')
$ffmpeg = Get-ChildItem -LiteralPath (Join-Path $work 'ffmpeg') -Recurse -Filter 'ffmpeg.exe' | Select-Object -First 1
if (-not $ffmpeg) { throw "ffmpeg.exe wasn't in the FFmpeg download" }
Copy-Item -LiteralPath $ffmpeg.FullName -Destination $bin -Force

# (ShareX.Setup is the project's own packaging tool, a console program; its CreatePortable job makes Output\ShareX-portable)
Say 'Making the portable version (ShareX.Setup -job CreatePortable)...'
Push-Location -LiteralPath $src
try { Invoke-Checked (Join-Path $src 'ShareX.Setup\bin\Release\win-x64\ShareX.Setup.exe') -silent -job CreatePortable -platform x64 }
finally { Pop-Location }

$portable = Join-Path $src 'Output\ShareX-portable'
if (-not (Test-Path -LiteralPath (Join-Path $portable 'ShareX.exe'))) { throw "ShareX.Setup didn't make $portable" }
Publish-Build -From $portable -Arch 'x64' -Version ($tag -replace '^v') -Note "Source: https://github.com/$repo, tag $tag; FFmpeg $ffmpegVersion from https://github.com/BtbN/FFmpeg-Builds"
Complete-Build
