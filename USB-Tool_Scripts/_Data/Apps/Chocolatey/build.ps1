# Builds Chocolatey CLI from source (github.com/chocolatey/choco) with its own Cake build, the way its Windows CI job
# does (.github\workflows\build.yml: build.ps1 --target=CI --testExecutionType=unit --shouldBuildMsi=true), into
# Built\x86: the chocolatey MSI (what update.cmd downloads, unsigned here) and the chocolatey .nupkg (which holds
# choco.exe in tools\chocolateyInstall)
# Needs: Visual Studio 2022 or its Build Tools with MSBuild, the C# compiler, the .NET SDK part and the .NET Framework
#        4.8 targeting pack (ILMerge looks for it in Program Files\Reference Assemblies); the .NET 5 runtime, which
#        the build's GitVersion tool runs on (a portable .NET 5 SDK is downloaded when this PC has none); Git (the
#        whole history, for GitVersion). Cake, NuGet, ILMerge and WiX 3 come as NuGet packages.
# Usage: build.cmd [-Version <x.y.z>] [-KeepWork] [-WorkDir <folder>]
param([string]$Version, [string]$WorkDir, [switch]$KeepWork, [switch]$Yes)
. "$PSScriptRoot\..\_Build-App.ps1"
trap { Stop-Build $_ }

$repo = 'chocolatey/choco'
# (its releases include 1.x maintenance ones, so the newest 2.x or later)
$tag = if ($Version) { $Version } else { Get-LatestGitHubTag $repo -Match '^[2-9]\.' }
$work = Start-Build -Name 'Chocolatey' -NeedGB 4
$src = Join-Path $work 'src'
# (with its history, for GitVersion; some test folders' paths are long, so git's core.longpaths)
$env:GIT_CONFIG_COUNT = '1'; $env:GIT_CONFIG_KEY_0 = 'core.longpaths'; $env:GIT_CONFIG_VALUE_0 = 'true'
$git = Get-Git
Say "Getting the source ($tag, with its history) from https://github.com/$repo.git..."
Invoke-Checked $git -c advice.detachedHead=false clone --branch $tag "https://github.com/$repo.git" $src

Use-VisualStudio -Arch x64 -Version '[17.0,18.0)' -Components 'Microsoft.Component.MSBuild', 'Microsoft.VisualStudio.Component.Roslyn.Compiler', 'Microsoft.NetCore.Component.SDK', 'Microsoft.Net.Component.4.8.TargetingPack' | Out-Null
# (GitVersion, a .NET 5 tool, as the workflow's "Install dotnet #needed for GitVersion" step sets up)
Use-Tool dotnet -Version '5.0'
$env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'; $env:DOTNET_NOLOGO = '1'

Say 'Building Chocolatey (Cake: build.ps1 --target=CI)...'
Push-Location -LiteralPath $src
try { Invoke-Checked powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $src 'build.ps1') --target=CI --testExecutionType=unit --shouldRunOpenCover=false --shouldBuildMsi=true }
finally { Pop-Location }

$out = Join-Path $work 'out'
New-Item -ItemType Directory -Path $out -Force | Out-Null
Get-ChildItem -LiteralPath (Join-Path $src 'code_drop\MSIs') -Recurse -Filter 'chocolatey-*.msi' -ErrorAction SilentlyContinue | Copy-Item -Destination $out
Get-ChildItem -LiteralPath (Join-Path $src 'code_drop\Packages\Chocolatey') -Filter 'chocolatey.*.nupkg' -ErrorAction SilentlyContinue | Copy-Item -Destination $out
if (-not (Get-ChildItem -LiteralPath $out)) { throw "The build made no MSI or package in $(Join-Path $src 'code_drop')" }
Publish-Build -From $out -Arch 'x86' -Version $tag -Note "Source: https://github.com/$repo, tag $tag (unsigned)"
Complete-Build
