param([string]$Version, [string]$WorkDir, [switch]$KeepWork, [switch]$Yes)
. "$PSScriptRoot\..\_Build-App.ps1"
trap { Stop-Build $_ }

# Builds Angry IP Scanner from source (github.com/angryip/ipscan) into Built\x86, the way its Windows CI job builds
# the release (Gradle's win64 task: the jar with SWT for Windows, shrunk with ProGuard, joined to the project's
# launcher exe with its version patched in by rcedit): ipscan-<version>-win.exe, the portable exe update.cmd
# downloads (it needs Java installed to run, like the official one). The installer (win-installer, NSIS) isn't built.
# Needs: a JDK 21 or newer (this PC's, or a portable Temurin is downloaded); Gradle downloads itself (gradlew)
# Usage: build.cmd [-Version <x.y.z>] [-KeepWork] [-WorkDir <folder>]

$repo = 'angryip/ipscan'
$tag = if ($Version) { $Version -replace '^v' } else { Get-LatestGitHubTag $repo }
$work = Start-Build -Name 'Angry IP Scanner' -NeedGB 2
# (the folder must be called ipscan: Gradle names the files after the project's folder)
$src = Join-Path $work 'ipscan'
Get-GitSource "https://github.com/$repo.git" $tag $src
# (build.gradle runs "git describe --tags" for the version)
Add-ToPath (Split-Path -Parent (Get-Git))

# (java -version writes to stderr, which Windows PowerShell turns into an error while ErrorActionPreference is Stop)
$ErrorActionPreference = 'Continue'
try { Use-Tool jdk -Version '21' } finally { $ErrorActionPreference = 'Stop' }
# (Gradle and its downloads go in the tools folder, not the user's profile)
$env:GRADLE_USER_HOME = Join-Path $script:toolsDir 'gradle-home'
Push-Location -LiteralPath $src
try {
    Say 'Building ipscan (gradlew win64)...'
    Invoke-Checked (Join-Path $src 'gradlew.bat') --no-daemon --max-workers=4 win64
}
finally { Pop-Location }

$exe = Join-Path $src "build\libs\ipscan-$tag-win.exe"
if (-not (Test-Path -LiteralPath $exe)) { throw "The build didn't make build\libs\ipscan-$tag-win.exe" }
Publish-Build -From $exe -Arch 'x86' -Version $tag -Note "Source: https://github.com/$repo, tag $tag"
Complete-Build
