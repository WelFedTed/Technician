# Builds mRemoteNG from source (github.com/mRemoteNG/mRemoteNG) into Built\x64 and Built\ARM64, like its nightly
# release's self-contained ("-SC") zips (.github\workflows\Build_mR-NB.yml: dotnet restore, then Visual Studio's
# MSBuild with the "Release Self-Contained" configuration): mRemoteNG.exe with the .NET 10 runtime beside it
# (The version is the one in the tag's Properties\AssemblyInfo.cs; the workflow regenerates it with T4 first, which
# gives a build number from the current time, so it's left as the release has it)
# Needs: the .NET 10 SDK (this PC's, or a portable copy), Visual Studio 2026 or its Build Tools with MSBuild, the C#
#        compiler, the .NET SDK part and the .NET Framework 4.8 SDK (AxImp, for the Remote Desktop ActiveX control)
# Usage: build.cmd [-Version <release tag, eg. 20261111-v1.78.2-NB-(3782)>] [-KeepWork] [-WorkDir <folder>]
param([string]$Version, [string]$WorkDir, [switch]$KeepWork, [switch]$Yes)
. "$PSScriptRoot\..\_Build-App.ps1"
trap { Stop-Build $_ }
# (for the helper) MSBuild.exe of a Visual Studio (or its Build Tools) with MSBuild, the C# compiler and -Components,
# for .NET projects that dotnet build can't do (COM references, .NET Framework resources). One without Visual
# Studio's .NET SDK part has no .NET SDK resolver, so it's pointed at the dotnet SDK's own Sdks folder (the SDK
# global.json picks), with satellite assemblies made by csc instead of al.exe (from the .NET Framework SDK, which
# isn't there either); that's enough for .NET Framework projects (but not .NET Core ones: ask for
# Microsoft.NetCore.Component.SDK for those)
function Use-DotnetMSBuild([string]$SourceDir, [string]$Version, [string[]]$Components = @()) {
    $need = @('Microsoft.Component.MSBuild', 'Microsoft.VisualStudio.Component.Roslyn.Compiler') + $Components
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    $q = @('-latest', '-products', '*', '-requires') + $need + @('-property', 'installationPath')
    if ($Version) { $q = @('-version', $Version) + $q }
    $vs = if (Test-Path -LiteralPath $vswhere) { & $vswhere @q | Select-Object -First 1 }
    if (-not $vs) {
        $vsName = if ($Version -match '^\[18') { 'Visual Studio 2026' } elseif ($Version -match '^\[17') { 'Visual Studio 2022' } else { 'Visual Studio' }
        Fail "This build needs $vsName (or its Build Tools) with: $($need -join ', '). Add them (Visual Studio Installer > Modify), then run build.cmd again"
    }
    $msbuild = Join-Path $vs 'MSBuild\Current\Bin\amd64\MSBuild.exe'
    if (-not (Test-Path -LiteralPath (Join-Path $vs 'MSBuild\Current\Bin\SdkResolvers\Microsoft.DotNet.MSBuildSdkResolver'))) {
        $dotnet = (Get-Command dotnet.exe | Select-Object -First 1).Source
        Push-Location -LiteralPath $SourceDir
        try { $sdk = "$(& $dotnet --version)".Trim() } finally { Pop-Location }
        $env:MSBuildSDKsPath = Join-Path (Split-Path -Parent $dotnet) "sdk\$sdk\Sdks"
        $env:MSBuildEnableWorkloadResolver = 'false'; $env:DOTNET_HOST_PATH = $dotnet; $env:GenerateSatelliteAssembliesForCore = 'true'
    }
    Say "Using $msbuild"
    return $msbuild
}

# (mRemoteNG's releases are all pre-releases: nightly builds tagged like 20261111-v1.78.2-NB-(3782))
$repo = 'mRemoteNG/mRemoteNG'
$tag = if ($Version) { $Version } else { Get-LatestGitHubTag $repo -Pre -Match '-NB-' }
$work = Start-Build -Name 'mRemoteNG' -NeedGB 4
$src = Join-Path $work 'src'
# (some of its paths are long: git's core.longpaths, through git's GIT_CONFIG_* variables)
$env:GIT_CONFIG_COUNT = '1'; $env:GIT_CONFIG_KEY_0 = 'core.longpaths'; $env:GIT_CONFIG_VALUE_0 = 'true'
Get-GitSource "https://github.com/$repo.git" $tag $src
Add-NuGetOrg $work

Use-Tool dotnet -Version '10.0'
$env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'; $env:DOTNET_NOLOGO = '1'
$msbuild = Use-DotnetMSBuild $src -Version '[18.0,19.0)' -Components 'Microsoft.NetCore.Component.SDK', 'Microsoft.Net.Component.4.8.SDK'
# (the workflow points MSBuild at the dotnet SDK on the PATH too)
$dotnetRoot = Split-Path -Parent (Get-Command dotnet.exe | Select-Object -First 1).Source
Push-Location -LiteralPath $src
try { $sdk = "$(& dotnet --version)".Trim() } finally { Pop-Location }
$env:MSBuildSDKsPath = Join-Path $dotnetRoot "sdk\$sdk\Sdks"; $env:DOTNET_MSBUILD_SDK_RESOLVER_CLI_DIR = $dotnetRoot; $env:DOTNET_ROOT = $dotnetRoot

$ver = ([regex]::Match([IO.File]::ReadAllText((Join-Path $src 'mRemoteNG\Properties\AssemblyInfo.cs')), 'AssemblyVersion\("([\d.]+)"\)')).Groups[1].Value
$project = Join-Path $src 'mRemoteNG\mRemoteNG.csproj'
foreach ($arch in @(@{ Platform = 'x64'; Rid = 'win-x64'; Folder = 'x64' }, @{ Platform = 'ARM64'; Rid = 'win-arm64'; Folder = 'ARM64' })) {
    Say "Building mRemoteNG for $($arch.Folder)..."
    $out = Join-Path $src "mRemoteNG\bin\$($arch.Platform)\$($arch.Rid -replace '^win-')\Release"
    Invoke-Checked dotnet restore $project '/p:Configuration=Release Self-Contained' "/p:Platform=$($arch.Platform)" /p:SelfContained=true "/p:RuntimeIdentifier=$($arch.Rid)" /p:PublishReadyToRun=true
    Invoke-Checked $msbuild $project '/p:Configuration=Release Self-Contained' "/p:Platform=$($arch.Platform)" /p:MSBuildEnableWorkloadResolver=false /m:4 /nologo /verbosity:minimal `
        /p:SelfContained=true "/p:RuntimeIdentifier=$($arch.Rid)" "/p:PublishDir=$out"
    if (-not (Test-Path -LiteralPath (Join-Path $out 'mRemoteNG.exe'))) { throw "The build didn't make $out\mRemoteNG.exe" }
    Publish-Build -From $out -Arch $arch.Folder -Version $ver -Note "Source: https://github.com/$repo, tag $tag (self-contained)"
}
Complete-Build