# Builds Bulk Crap Uninstaller from source (github.com/BCUninstaller/Bulk-Crap-Uninstaller) into Built\x86_x64, laid
# out like its portable release (publish.bat): BCUninstaller.exe (the small C++ launcher that starts the right one)
# with win-x64\ and win-arm64\ (self-contained .NET 8 publishes of BCU and its helper programs)
# Needs: Visual Studio 2022 with the C++ x86/x64 tools (the launcher) and the .NET desktop build parts (the .NET SDK,
#        the .NET Framework 4.8 SDK's TlbImp/AxImp and the C# compiler: some projects have COM references, which
#        only Visual Studio's MSBuild can build, not dotnet build)
# Usage: build.cmd [-Version <x.y>] [-KeepWork] [-WorkDir <folder>]
param([string]$Version, [string]$WorkDir, [switch]$KeepWork, [switch]$Yes)
. "$PSScriptRoot\..\_Build-App.ps1"
trap { Stop-Build $_ }

$repo = 'BCUninstaller/Bulk-Crap-Uninstaller'
$tag = if ($Version) { 'v' + ($Version -replace '^v') } else { Get-LatestGitHubTag $repo }
$work = Start-Build -Name 'Bulk Crap Uninstaller (BCU)' -NeedGB 4
$src = Join-Path $work 'src'
Get-GitSource "https://github.com/$repo.git" $tag $src
Add-NuGetOrg $work

# (the launcher is always 32-bit; this Visual Studio's MSBuild builds the .NET projects too, like the CI and publish.bat)
Use-VisualStudio -Arch x86 -Version '[17.0,18.0)' -Components 'Microsoft.VisualStudio.Component.VC.Tools.x86.x64', 'Microsoft.NetCore.Component.SDK', 'Microsoft.Net.Component.4.8.SDK', 'Microsoft.VisualStudio.Component.Roslyn.Compiler' | Out-Null
Use-Tool dotnet -Version '8.0'
$env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'; $env:DOTNET_NOLOGO = '1'

$source = Join-Path $src 'source'
$publish = Join-Path $work 'publish'

Say 'Building the launcher (BCU-launcher)...'
# (it's marked as using MFC, but only needs the Windows SDK, so it builds without the MFC component; folders passed
# to MSBuild end in \\, since a single \ before the closing quote PowerShell adds would escape that quote)
Invoke-Checked msbuild (Join-Path $source 'BCU-launcher\BCU-launcher.vcxproj') /t:Build /p:Configuration=Release /p:Platform=Win32 "/p:SolutionDir=$source\\" /p:UseOfMfc=false /m:4 /nologo /verbosity:minimal

# (every project that makes a program, published for each platform like publish.bat does)
$projects = Get-ChildItem -LiteralPath $source -Recurse -Filter '*.csproj' | Where-Object { (Get-Content -LiteralPath $_.FullName -Raw) -match 'exe</OutputType>' }
foreach ($platform in @(@{ Name = 'x64'; Rid = 'win-x64' }, @{ Name = 'ARM64'; Rid = 'win-arm64' })) {
    $target = Join-Path $publish $platform.Rid
    foreach ($project in $projects) {
        Say "Publishing $($project.BaseName) for $($platform.Rid)..."
        Invoke-Checked msbuild $project.FullName /restore /m:4 /nologo /verbosity:minimal /t:Publish /p:Configuration=Release "/p:Platform=$($platform.Name)" `
            /p:filealignment=512 /p:DeployOnBuild=true /p:PublishSingleFile=False /p:SelfContained=True /p:PublishProtocol=FileSystem `
            /p:TargetFramework=net8.0-windows10.0.18362.0 "/p:PublishDir=$target\\" "/p:RuntimeIdentifier=$($platform.Rid)" /p:PublishReadyToRun=false /p:PublishTrimmed=False
    }
}

Copy-Item -LiteralPath (Join-Path $src 'bin\launcher\BCU-launcher.exe') -Destination (Join-Path $publish 'BCUninstaller.exe')
foreach ($f in 'BCU_manual.html', 'Licence.txt', 'PrivacyPolicy.txt', 'NOTICE') { Copy-Item -LiteralPath (Join-Path $publish "win-x64\$f") -Destination $publish }
Get-ChildItem -LiteralPath $publish -Recurse -Filter '*.pdb' | Remove-Item -Force

Publish-Build -From $publish -Arch 'x86_x64' -Version ($tag -replace '^v') -Note "Source: https://github.com/$repo, tag $tag"
Complete-Build
