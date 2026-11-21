param([string]$Version, [string]$WorkDir, [switch]$KeepWork, [switch]$Yes)
. "$PSScriptRoot\..\..\_Build-App.ps1"
trap { Stop-Build $_ }

# Builds Windows Terminal from source (github.com/microsoft/terminal) into Built\x64 and Built\x86 (and Built\ARM64
# when Visual Studio has its ARM64 C++ / UWP tools) like the portable zips update.cmd downloads, the way its release
# pipeline does (build/pipelines/templates-v2/job-build-project.yml): NuGet restore, vcpkg (fmt, ms-gsl, jsoncpp,
# CLI11, cmark), MSBuild of OpenConsole.slnx's Terminal\CascadiaPackage target (Release, WindowsTerminalBranding=Release,
# WindowsTerminalOfficialBuild=true) which makes the MSIX, then build/scripts/New-UnpackagedTerminalDistribution.ps1
# turns that MSIX and its Microsoft.UI.Xaml appx into the unpackaged distribution (WindowsTerminal.exe, OpenConsole.exe,
# Microsoft.UI.Xaml.dll and the rest).
# Differences: not code-signed, and no PGO profile (PGOBuildMode=None).
# Needs: Visual Studio 2022 with C++, its UWP C++ tools and MSIX packaging (the -Components below; the project's
#        .vsconfig lists the full set), the Windows 11 SDK (10.0.26100); NuGet and vcpkg are downloaded into the tools folder
# Usage: build.cmd [-Version <x.y.z.w>] [-KeepWork] [-WorkDir <folder>]

$repo = 'microsoft/terminal'
$tag = if ($Version) { 'v' + ($Version -replace '^v') } else { Get-LatestGitHubTag $repo }
$ver = $tag -replace '^v'
$work = Start-Build -Name 'Windows Terminal' -NeedGB 25
$env:GIT_CONFIG_COUNT = '1'; $env:GIT_CONFIG_KEY_0 = 'core.longpaths'; $env:GIT_CONFIG_VALUE_0 = 'true'
$src = Join-Path $work 'src'
Get-GitSource "https://github.com/$repo.git" $tag $src -Submodules

# (the project's own scripts are written for PowerShell 7, which the pipeline runs them with; Windows PowerShell otherwise)
$pwsh = Get-Command pwsh.exe -ErrorAction SilentlyContinue | Select-Object -First 1
$psExe = if ($pwsh) { $pwsh.Source } else { 'powershell.exe' }

# nuget.exe (for the packages.config restores), in the tools folder; the repository's NuGet.Config names its feed
$nuget = Join-Path $script:toolsDir 'nuget\nuget.exe'
if (-not (Test-Path -LiteralPath $nuget)) { Get-File 'https://dist.nuget.org/win-x86-commandline/latest/nuget.exe' $nuget }
Push-Location -LiteralPath $src
try {
    Say 'Restoring the NuGet packages (build tools and global packages)...'
    foreach ($config in 'build\packages.config', 'dep\nuget\packages.config') {
        Invoke-Checked $nuget restore $config -ConfigFile NuGet.Config -PackagesDirectory packages -NonInteractive
    }
    # (the NOTICE.html the package includes, as the pipeline makes it)
    & $psExe -NoProfile -ExecutionPolicy Bypass -File .\build\scripts\Generate-ThirdPartyNotices.ps1 -MarkdownNoticePath .\NOTICE.md -OutputPath .\src\cascadia\CascadiaPackage\NOTICE.html
    if ($LASTEXITCODE -ne 0) { throw 'Generate-ThirdPartyNotices.ps1 failed' }
}
finally { Pop-Location }

# vcpkg (as the pipeline does when Visual Studio has no vcpkg part: a checkout of it), in the tools folder
$vcpkg = Join-Path $script:toolsDir 'vcpkg'
$git = Get-Git
if (-not (Test-Path -LiteralPath (Join-Path $vcpkg '.git'))) { Say 'Getting vcpkg...'; Invoke-Checked $git clone -q https://github.com/microsoft/vcpkg.git $vcpkg }
else { Invoke-Checked $git -C $vcpkg pull -q --ff-only }
if (-not (Test-Path -LiteralPath (Join-Path $vcpkg 'vcpkg.exe'))) { Invoke-Checked (Join-Path $vcpkg 'bootstrap-vcpkg.bat') -disableMetrics }
$env:VCPKG_ROOT = $vcpkg; $env:VCPKG_DISABLE_METRICS = '1'; $env:VCPKG_MAX_CONCURRENCY = '4'
$env:VCPKG_DOWNLOADS = Join-Path $script:toolsDir 'vcpkg-downloads'
$env:VCPKG_DEFAULT_BINARY_CACHE = Join-Path $script:toolsDir 'vcpkg-cache'
New-Item -ItemType Directory -Path $env:VCPKG_DOWNLOADS, $env:VCPKG_DEFAULT_BINARY_CACHE -Force | Out-Null

$env:PATH = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer;$env:PATH"
$env:MSBUILDDISABLENODEREUSE = '1'
$cleanEnv = @{}; Get-ChildItem Env: | ForEach-Object { $cleanEnv[$_.Name] = $_.Value }
function Reset-Env { Get-ChildItem Env: | Where-Object { -not $cleanEnv.ContainsKey($_.Name) } | ForEach-Object { Remove-Item -LiteralPath "Env:$($_.Name)" }; foreach ($k in $cleanEnv.Keys) { Set-Item -LiteralPath "Env:$k" -Value $cleanEnv[$k] } }
function Test-VSComponent([string[]]$Components) {
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    return [bool](& $vswhere -version '[17.0,18.0)' -products * -requires $Components -property installationPath)
}
# (the parts of the .vsconfig a command-line build of the Terminal package uses)
$components = 'Microsoft.VisualStudio.Component.VC.Tools.x86.x64', 'Microsoft.VisualStudio.Component.Windows11SDK.26100',
    'Microsoft.VisualStudio.ComponentGroup.UWP.VC', 'Microsoft.VisualStudio.ComponentGroup.MSIX.Packaging',
    'Microsoft.VisualStudio.ComponentGroup.NativeDesktop.Core', 'Microsoft.VisualStudio.Component.VC.Redist.14.Latest'
$makeAppx = Get-ChildItem -Path "${env:ProgramFiles(x86)}\Windows Kits\10\bin\10.0.*\x64\MakeAppx.exe" -ErrorAction SilentlyContinue | Sort-Object { [version]$_.Directory.Parent.Name } | Select-Object -Last 1

foreach ($arch in @(
        @{ Platform = 'x64'; Folder = 'x64' },
        @{ Platform = 'x86'; Folder = 'x86' },
        @{ Platform = 'ARM64'; Folder = 'ARM64'; Needs = @('Microsoft.VisualStudio.Component.VC.Tools.ARM64', 'Microsoft.VisualStudio.Component.UWP.VC.ARM64') })) {
    if ($arch.Needs -and -not (Test-VSComponent $arch.Needs)) { Say "Skipping $($arch.Folder): Visual Studio 2022 doesn't have $($arch.Needs -join ', ')"; continue }
    Reset-Env
    Use-VisualStudio -Arch 'x64' -Version '[17.0,18.0)' -Components ($components + @($arch.Needs | Where-Object { $_ })) | Out-Null
    if (-not $makeAppx) { throw "Couldn't find the Windows SDK's MakeAppx.exe" }
    $sln = Join-Path $src 'OpenConsole.slnx'
    $props = "/p:Configuration=Release", "/p:Platform=$($arch.Platform)", '/p:WindowsTerminalOfficialBuild=true', '/p:WindowsTerminalBranding=Release', '/p:PGOBuildMode=None'
    Say "Restoring OpenConsole.slnx for $($arch.Folder)..."
    Invoke-Checked msbuild $sln /nologo /verbosity:minimal /t:Restore @props
    Say "Building Windows Terminal $ver for $($arch.Folder) (Terminal\CascadiaPackage)..."
    Invoke-Checked msbuild $sln /nologo /verbosity:minimal /m:4 /p:CL_MPCount=1 '/t:Terminal\CascadiaPackage' @props

    # the MSIX it made and the Microsoft.UI.Xaml appx beside it, made into the unpackaged (portable) distribution
    $packages = Join-Path $src 'src\cascadia\CascadiaPackage\AppPackages'
    $msix = Get-ChildItem -LiteralPath $packages -Recurse -Filter "*_$($arch.Platform).msix" | Where-Object { $_.FullName -notmatch '\\Dependencies\\' } | Sort-Object LastWriteTime | Select-Object -Last 1
    $xaml = Get-ChildItem -LiteralPath $packages -Recurse -Filter 'Microsoft.UI.Xaml*.appx' | Where-Object { $_.FullName -match "\\Dependencies\\$($arch.Platform)\\" } | Select-Object -First 1
    if (-not $msix -or -not $xaml) { throw "The build didn't make the Terminal MSIX and its Microsoft.UI.Xaml appx in $packages" }
    $unpackaged = Join-Path $work "unpackaged\$($arch.Folder)"
    New-Item -ItemType Directory -Path $unpackaged -Force | Out-Null
    & $psExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $src 'build\scripts\New-UnpackagedTerminalDistribution.ps1') -TerminalAppX $msix.FullName -XamlAppX $xaml.FullName -Destination $unpackaged -MakeAppxPath $makeAppx.FullName
    if ($LASTEXITCODE -ne 0) { throw 'New-UnpackagedTerminalDistribution.ps1 failed' }
    # (it makes a zip holding one folder, terminal-<version>; that folder is what goes into Built)
    $zip = Get-ChildItem -LiteralPath $unpackaged -Filter '*.zip' | Select-Object -First 1
    if (-not $zip) { throw "New-UnpackagedTerminalDistribution.ps1 made no zip in $unpackaged" }
    $x = Join-Path $unpackaged 'x'
    [IO.Compression.ZipFile]::ExtractToDirectory($zip.FullName, $x)
    $top = @(Get-ChildItem -LiteralPath $x)
    $from = if ($top.Count -eq 1 -and $top[0].PSIsContainer) { $top[0].FullName } else { $x }
    Publish-Build -From $from -Arch $arch.Folder -Version $ver -Note "Source: https://github.com/$repo, tag $tag (Release branding, unsigned, no PGO)"
}
Complete-Build
