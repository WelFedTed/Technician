param([string]$Version, [string]$WorkDir, [switch]$KeepWork, [switch]$Yes)
. "$PSScriptRoot\..\_Build-App.ps1"
trap { Stop-Build $_ }

# Builds PowerToys from source (github.com/microsoft/PowerToys) into Built\x64 (and Built\ARM64 when Visual Studio
# has its ARM64 C++ tools), the way its CI pipeline builds the main solution (.pipelines/v2/templates/
# job-build-project.yml): nuget restore of packages.config, then MSBuild of PowerToys.slnx with "-restore -graph
# /p:RestorePackagesConfig=true /p:CIBuild=true" (Release, no tests), with Visual Studio 2026 (the pipeline's
# vsVersion 18.0) and the .NET 10 SDK. Built\<arch> gets the built program folder (PowerToys.exe, the modules and
# WinUI3Apps\), without the .pdb / .lib files.
# Differences: no installer (tools/build/build-installer.ps1 signs the MSIX parts with a certificate it adds to the
# user's certificate store and builds WiX 5 bundles, so it isn't run); not code-signed, so the parts that need
# package identity (the MSIX-based modules, eg. the File Explorer context menu) won't register from this folder.
# Needs: Visual Studio 2026 (or its Build Tools) with C++, ATL, UWP C++, the Windows App SDK C++ / C# parts, .NET
#        desktop and the Windows 11 SDKs (the -Components below, from the project's .vsconfig); the .NET 10 SDK (this
#        PC's, or a portable copy); NuGet is downloaded into the tools folder. A long build (an hour or more), ~30 GB.
# Usage: build.cmd [-Version <x.y.z>] [-KeepWork] [-WorkDir <folder>]

$repo = 'microsoft/PowerToys'
$tag = if ($Version) { 'v' + ($Version -replace '^v') } else { Get-LatestGitHubTag $repo }
$ver = $tag -replace '^v'
$work = Start-Build -Name 'PowerToys' -NeedGB 30
$env:GIT_CONFIG_COUNT = '1'; $env:GIT_CONFIG_KEY_0 = 'core.longpaths'; $env:GIT_CONFIG_VALUE_0 = 'true'
$src = Join-Path $work 'src'
Get-GitSource "https://github.com/$repo.git" $tag $src -Submodules

# nuget.exe for packages.config (the repository's nuget.config names its feed), in the tools folder
$nuget = Join-Path $script:toolsDir 'nuget\nuget.exe'
if (-not (Test-Path -LiteralPath $nuget)) { Get-File 'https://dist.nuget.org/win-x86-commandline/latest/nuget.exe' $nuget }
Push-Location -LiteralPath $src
try {
    Say 'Restoring the NuGet packages (packages.config)...'
    Invoke-Checked $nuget restore packages.config -ConfigFile nuget.config -PackagesDirectory packages -NonInteractive
}
finally { Pop-Location }

Use-Tool dotnet -Version '10.0'
$env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'; $env:DOTNET_NOLOGO = '1'
$env:PATH = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer;$env:PATH"
$env:MSBUILDDISABLENODEREUSE = '1'
$cleanEnv = @{}; Get-ChildItem Env: | ForEach-Object { $cleanEnv[$_.Name] = $_.Value }
function Reset-Env { Get-ChildItem Env: | Where-Object { -not $cleanEnv.ContainsKey($_.Name) } | ForEach-Object { Remove-Item -LiteralPath "Env:$($_.Name)" }; foreach ($k in $cleanEnv.Keys) { Set-Item -LiteralPath "Env:$k" -Value $cleanEnv[$k] } }
function Test-VSComponent([string[]]$Components) {
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    return [bool](& $vswhere -version '[18.0,19.0)' -products * -requires $Components -property installationPath)
}
# (the project's .vsconfig, without the editor and the ARM64 parts)
$components = 'Microsoft.VisualStudio.Component.VC.Tools.x86.x64', 'Microsoft.VisualStudio.Workload.NativeDesktop',
    'Microsoft.VisualStudio.Workload.ManagedDesktop', 'Microsoft.VisualStudio.Workload.Universal',
    'Microsoft.VisualStudio.Component.Windows11SDK.22621', 'Microsoft.VisualStudio.Component.Windows11SDK.26100',
    'Microsoft.VisualStudio.ComponentGroup.UWP.VC', 'Microsoft.VisualStudio.Component.VC.ATL', 'Microsoft.VisualStudio.Component.Vcpkg',
    'Microsoft.VisualStudio.Component.WindowsAppSdkSupport.CSharp', 'Microsoft.VisualStudio.Component.WindowsAppSdkSupport.Cpp'

foreach ($arch in @(
        @{ Platform = 'x64'; Folder = 'x64' },
        @{ Platform = 'arm64'; Folder = 'ARM64'; Needs = @('Microsoft.VisualStudio.Component.VC.Tools.ARM64', 'Microsoft.VisualStudio.Component.UWP.VC.ARM64', 'Microsoft.VisualStudio.Component.VC.ATL.ARM64') })) {
    if ($arch.Needs -and -not (Test-VSComponent $arch.Needs)) { Say "Skipping $($arch.Folder): Visual Studio 2026 doesn't have $($arch.Needs -join ', ')"; continue }
    Reset-Env
    Use-VisualStudio -Arch 'x64' -Version '[18.0,19.0)' -Components ($components + @($arch.Needs | Where-Object { $_ })) | Out-Null
    Say "Building PowerToys $ver for $($arch.Folder) (PowerToys.slnx)..."
    Push-Location -LiteralPath $src
    try {
        Invoke-Checked msbuild PowerToys.slnx /restore /graph /nologo /verbosity:minimal /m:4 /p:CL_MPCount=1 /p:RestorePackagesConfig=true /p:CIBuild=true /p:BuildTests=false /p:Configuration=Release "/p:Platform=$($arch.Platform)"
    }
    finally { Pop-Location }
    $out = Join-Path $src "$($arch.Platform)\Release"
    if (-not (Test-Path -LiteralPath (Join-Path $out 'PowerToys.exe'))) { throw "The build didn't make $out\PowerToys.exe" }
    # (the program folder, without debug symbols, static / import libraries and linker leftovers)
    $clean = Join-Path $work "out\$($arch.Folder)"
    Say "Copying the program files from $out..."
    & robocopy.exe $out $clean /E /NFL /NDL /NJH /NJS /NP /XF *.pdb *.lib *.exp *.ilk *.iobj *.ipdb *.metagen /XD obj | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "Couldn't copy $out (robocopy exit code $LASTEXITCODE)" }
    Publish-Build -From $clean -Arch $arch.Folder -Version $ver -Note "Source: https://github.com/$repo, tag $tag (program folder from PowerToys.slnx, no installer, unsigned)"
}
Complete-Build
