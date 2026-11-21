param([string]$Version, [string]$WorkDir, [switch]$KeepWork, [switch]$Yes)
. "$PSScriptRoot\..\_Build-App.ps1"
trap { Stop-Build $_ }

# Builds System Informer from source (github.com/winsiderss/systeminformer) into Built\x64, Built\x86 and Built\ARM64,
# the way its release workflow (.github\workflows\msbuild.yml, build-release) does: NuGet restore of packages.config
# (the Windows SDK / WDK packages), build\build_init.cmd (third-party libraries and CustomBuildTool, a .NET 10 tool),
# then build\build_release.cmd (System Informer and its plugins for x86, x64 and ARM64, and the -bin.zip); each
# Built\<arch> is that zip's amd64 / i386 / arm64 folder, as update.cmd uses the official one
# Differences: the kernel driver (KSystemInformer, ksi.dll) isn't built or signed: System Informer runs without it
# (as with the official build when the driver is off), with fewer details about protected processes; the version's
# last two numbers come from the build time, the way CustomBuildTool numbers its builds
# The project expects Visual Studio 2026 with the parts CustomBuildTool checks for (see -Components below), and the
# .NET 10 SDK
# Needs: Visual Studio 2026 with the C++ tools, ARM64 C++ tools, ATL/MFC, the Windows SDK and WDK, Spectre runtimes;
#        .NET 10 SDK (a portable one is downloaded when missing); nuget.exe (downloaded into the tools folder)
# Usage: build.cmd [-Version <x.y.z.w>] [-KeepWork] [-WorkDir <folder>]

$repo = 'winsiderss/systeminformer'
$tag = if ($Version) { 'v' + ($Version -replace '^v') } else { Get-LatestGitHubTag $repo }
$ver = $tag -replace '^v'
$work = Start-Build -Name 'System Informer' -NeedGB 12
$src = Join-Path $work 'src'
Get-GitSource "https://github.com/$repo.git" $tag $src

Use-Tool dotnet -Version '10.0'

# (the parts CustomBuildTool requires; its build scripts use the newest Visual Studio)
Use-VisualStudio -Arch x64 -Version '[18.0,19.0)' -Components @(
    'Microsoft.VisualStudio.Component.VC.Tools.x86.x64', 'Microsoft.VisualStudio.Component.VC.Tools.ARM64',
    'Microsoft.VisualStudio.Component.Windows11SDK.26100', 'Component.Microsoft.Windows.DriverKit',
    'Microsoft.VisualStudio.Component.VC.ATL', 'Microsoft.VisualStudio.Component.VC.ATLMFC',
    'Microsoft.VisualStudio.Component.VC.Redist.14.Latest', 'Microsoft.VisualStudio.Component.VC.Runtimes.x86.x64.Spectre',
    'Microsoft.VisualStudio.Component.VC.Runtimes.ARM64.Spectre', 'Microsoft.VisualStudio.Component.VC.Runtimes.ARM64EC.Spectre',
    'Microsoft.VisualStudio.Component.NuGet', 'Microsoft.VisualStudio.Component.Git') | Out-Null
$nuget = Join-Path $script:toolsDir 'nuget\nuget.exe'
if (-not (Test-Path -LiteralPath $nuget)) { Say 'Getting nuget.exe...'; Get-File 'https://dist.nuget.org/win-x86-commandline/latest/nuget.exe' $nuget }
# (from nuget.org, with NuGet's package cache in the tools folder instead of the user's profile)
$env:NUGET_PACKAGES = Join-Path $script:toolsDir 'nuget\packages'
Invoke-Checked $nuget restore (Join-Path $src 'packages.config') -PackagesDirectory (Join-Path $src 'packages') -NonInteractive -Source https://api.nuget.org/v3/index.json

# (the version's first two numbers, as the release pipeline sets them; the build scripts don't pause with no console input)
$parts = $ver.Split('.')
$env:BUILD_MAJORVERSION = $parts[0]; $env:BUILD_MINORVERSION = $parts[1]; $env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'
Push-Location -LiteralPath $src
try {
    Say 'Building the third-party libraries and CustomBuildTool (build_init.cmd)...'
    & cmd.exe /d /c "build\build_init.cmd INIT < NUL"
    if ($LASTEXITCODE -ne 0) { throw "build_init.cmd failed (exit code $LASTEXITCODE)" }
    Say "Building System Informer $ver (build_release.cmd)..."
    & cmd.exe /d /c "build\build_release.cmd < NUL"
    if ($LASTEXITCODE -ne 0) { throw "build_release.cmd failed (exit code $LASTEXITCODE)" }
}
finally { Pop-Location }

$zip = Get-ChildItem -LiteralPath (Join-Path $src 'build\output') -Filter '*-bin.zip' | Select-Object -First 1
if (-not $zip) { throw "The build didn't make the -bin.zip in build\output" }
$bin = Join-Path $work 'bin'
Expand-Archive7 $zip.FullName $bin
foreach ($arch in @(@{ Inner = 'amd64'; Folder = 'x64' }, @{ Inner = 'i386'; Folder = 'x86' }, @{ Inner = 'arm64'; Folder = 'ARM64' })) {
    if (-not (Test-Path -LiteralPath (Join-Path $bin $arch.Inner))) { Say "(no $($arch.Inner) folder in $($zip.Name))"; continue }
    Publish-Build -From (Join-Path $bin $arch.Inner) -Arch $arch.Folder -Version $ver -Note "Source: https://github.com/$repo, tag $tag (no kernel driver: see build.ps1)"
}
Complete-Build
