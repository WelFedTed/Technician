# Builds DriverStore Explorer from source (github.com/lostindark/DriverStoreExplorer) into Built\Any, the way its CI
# builds the release (.github\workflows\ci.yml: the release tag's version patched into AssemblyInfo, then MSBuild):
# Rapr.exe (.NET Framework 4.7.2, with its libraries and translations embedded), Rapr.exe.config and Rapr.pdb
# Needs: the .NET SDK (this PC's, or a portable copy), and MSBuild with the C# compiler from Visual Studio or its
#        Build Tools (dotnet build can't make this project's .NET Framework resources)
# Usage: build.cmd [-Version <x.y.z>] [-KeepWork] [-WorkDir <folder>]
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

$repo = 'lostindark/DriverStoreExplorer'
$tag = if ($Version) { 'v' + ($Version -replace '^v') } else { Get-LatestGitHubTag $repo }
$ver = $tag -replace '^v'
$work = Start-Build -Name 'DriverStore Explorer (RAPR)' -NeedGB 1
$src = Join-Path $work 'src'
Get-GitSource "https://github.com/$repo.git" $tag $src
Add-NuGetOrg $work

Use-Tool dotnet -Version '8.0'
$env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'; $env:DOTNET_NOLOGO = '1'
$msbuild = Use-DotnetMSBuild $src

# (the CI's "Patch assembly version" step)
$info = Join-Path $src 'Rapr\Properties\AssemblyInfo.cs'
$text = [IO.File]::ReadAllText($info)
$text = $text -replace 'AssemblyVersion\(".*?"\)', "AssemblyVersion(`"$ver`")" -replace 'AssemblyFileVersion\(".*?"\)', "AssemblyFileVersion(`"$ver`")" -replace 'AssemblyInformationalVersion\(".*?"\)', "AssemblyInformationalVersion(`"$ver`")"
[IO.File]::WriteAllText($info, $text)

Say 'Building DriverStore Explorer...'
Invoke-Checked $msbuild (Join-Path $src 'Rapr\Rapr.csproj') /restore /m:4 /nologo /verbosity:minimal /p:Configuration=Release

Publish-Build -From (Join-Path $src 'Rapr\bin\Release') -Arch 'Any' -Version $ver -Files 'Rapr.exe', 'Rapr.exe.config', 'Rapr.pdb' -Note "Source: https://github.com/$repo, tag $tag"
Complete-Build
