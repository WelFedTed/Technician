# Builds Greenshot from source (github.com/greenshot/greenshot) the way its release workflow does
# (.github\workflows\release.yml: MSBuild of src\Greenshot.sln, which also makes the Inno Setup installer, then
# prepare-portable.ps1): the portable version into Built\Any and the installer into Built\x86
# (The upload plugins' API keys are GitHub secrets, so Box, Dropbox, Flickr, Imgur, Photobucket and Google Photos
# uploads won't work in this build until you set their ..._ClientId / ..._ClientSecret environment variables)
# Needs: the .NET SDK (this PC's, or a portable copy), MSBuild with the C# compiler from Visual Studio or its Build
#        Tools (.NET Framework 4.7.2 WinForms/WPF projects), Git (the whole release branch's history, for the version)
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

$repo = 'greenshot/greenshot'
$tag = if ($Version) { 'v' + ($Version -replace '^v') } else { Get-LatestGitHubTag $repo }
$ver = $tag -replace '^v'
$work = Start-Build -Name 'Greenshot' -NeedGB 2
$src = Join-Path $work 'src'
# (not a shallow clone: Nerdbank.GitVersioning counts the commits since version.json changed for the version number)
$git = Get-Git
Say "Getting the source ($tag, with its history) from https://github.com/$repo.git..."
Invoke-Checked $git -c advice.detachedHead=false clone --single-branch --no-tags --branch $tag "https://github.com/$repo.git" $src
Add-NuGetOrg $work

Use-Tool dotnet -Version '8.0'
$env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'; $env:DOTNET_NOLOGO = '1'
$msbuild = Use-DotnetMSBuild $src

Say 'Building Greenshot (and its installer)...'
# (PublicRelease: a release build's version, without the commit id that a build outside a release/* branch gets)
$sln = Join-Path $src 'src\Greenshot.sln'
# (first the restore and PrepareForBuild, which makes the plugins' *.Credentials.cs from their templates, then the
# build in a second run, so it sees those files: the workflow's two steps. Inno Setup's compiler, run at the end,
# doesn't take paths over 260 characters, so a deep -WorkDir can make it fail)
Invoke-Checked $msbuild $sln /restore /t:PrepareForBuild /m:4 /nologo /verbosity:minimal /p:Configuration=Release /p:PublicRelease=true
Invoke-Checked $msbuild $sln /t:Build /m:4 /nologo /verbosity:minimal /p:Configuration=Release /p:PublicRelease=true

$out = Join-Path $src 'src\Greenshot\bin\Release\net472'
$portable = Join-Path $work 'portable'
Say 'Making the portable version (prepare-portable.ps1)...'
& (Join-Path $src 'prepare-portable.ps1') -RepositoryRootPath $src -BuildArtifactsPath $out -OutputPath $portable
Publish-Build -From $portable -Arch 'Any' -Version $ver -Note "Source: https://github.com/$repo, tag $tag (portable version)"

$installer = Get-ChildItem -LiteralPath (Join-Path $src 'installer') -Filter 'Greenshot-INSTALLER-*.exe' | Select-Object -First 1
if ($installer) { Publish-Build -From $installer.FullName -Arch 'x86' -Version $ver -Note "Source: https://github.com/$repo, tag $tag (installer, unsigned)" }
else { Say "(the build made no installer in $(Join-Path $src 'installer'))" }
Complete-Build
