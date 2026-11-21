param([string]$Version, [string]$WorkDir, [switch]$KeepWork, [switch]$Yes)
. "$PSScriptRoot\..\_Build-App.ps1"
trap { Stop-Build $_ }

# Builds Open-Shell from source (github.com/Open-Shell/Open-Shell-Menu) into Built\x86, the way its release build
# (Src\Setup\__MakeFinal.bat > BuildBinaries.bat) compiles it: msbuild Src\OpenShell.sln, configuration "Setup",
# for x64, ARM64 and Win32, with the version from the release tag (CS_VERSION)
# Built\x86 has the files the installer is made from (BuildBinaries.bat's Output folder): the 32-bit programs and
# skins, with the 64-bit ones in x64\ and ARM64\
# Not built: the installer itself (OpenShellSetup_*.exe, which needs WiX 3 and HTML Help Workshop), the help file,
# the ADMX policy files and the debug symbols. Open-Shell is a shell extension, so these files are for developers /
# testing: to use it on a PC, install the official OpenShellSetup (install.cmd)
# ARM64 is built only when Visual Studio has its ARM64 C++ tools and ARM64 ATL
# Needs: Visual Studio 2022 with the C++ tools and ATL (Microsoft.VisualStudio.Component.VC.ATL)
# Usage: build.cmd [-Version <x.y.z>] [-KeepWork] [-WorkDir <folder>]

$repo = 'Open-Shell/Open-Shell-Menu'
$tag = if ($Version) { 'v' + ($Version -replace '^v') } else { Get-LatestGitHubTag $repo }
$ver = $tag -replace '^v'
$work = Start-Build -Name 'Open-Shell' -NeedGB 3
$src = Join-Path $work 'src'
Get-GitSource "https://github.com/$repo.git" $tag $src

function Test-VSComponent([string[]]$Components) {
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    return [bool](& $vswhere -version '[17.0,18.0)' -products * -requires $Components -property installationPath)
}

Use-VisualStudio -Arch x64 -Version '[17.0,18.0)' -Components @('Microsoft.VisualStudio.Component.VC.Tools.x86.x64', 'Microsoft.VisualStudio.Component.VC.ATL') | Out-Null
$env:CS_VERSION = $ver; $env:CS_VERSION_ORIG = $ver
$sln = Join-Path $src 'Src\OpenShell.sln'
# (NuGet packages from nuget.org, with NuGet's cache in the tools folder instead of the user's profile)
$env:NUGET_PACKAGES = Join-Path $script:toolsDir 'nuget\packages'
# (a packages.config restore ignores RestoreSources, so nuget.org comes from a NuGet.Config above the source)
Add-NuGetOrg $work
Invoke-Checked msbuild $sln /m:2 /t:Restore /p:RestorePackagesConfig=true /nologo /v:minimal

# (x64 and ARM64 first, then Win32, as BuildBinaries.bat does)
$arm64 = Test-VSComponent @('Microsoft.VisualStudio.Component.VC.Tools.ARM64', 'Microsoft.VisualStudio.Component.VC.ATL.ARM64')
foreach ($platform in @('x64', 'ARM64', 'Win32')) {
    if ($platform -eq 'ARM64' -and -not $arm64) { Say "Skipping ARM64: Visual Studio 2022 doesn't have its ARM64 C++ tools and ATL"; continue }
    Say "Building Open-Shell $ver for $platform..."
    Invoke-Checked msbuild $sln /m:2 /p:CL_MPCount=2 /t:Rebuild /p:Configuration=Setup "/p:Platform=$platform" /nologo /v:minimal
}

# (BuildBinaries.bat's Output folder)
$bin = Join-Path $src 'build\bin'
$out = Join-Path $work 'out\x86'
New-Item -ItemType Directory -Path (Join-Path $out 'x64') -Force | Out-Null
foreach ($f in 'ClassicExplorer32.dll', 'ClassicExplorerSettings.exe', 'ClassicIEDLL_32.dll', 'ClassicIE_32.exe', 'StartMenu.exe', 'StartMenuDLL.dll', 'StartMenuHelper32.dll') { Copy-Item -LiteralPath (Join-Path $bin "Setup\$f") -Destination $out }
foreach ($f in 'Update.exe', 'DesktopToasts.dll', 'SetupHelper.exe') { Copy-Item -LiteralPath (Join-Path $bin "Release\$f") -Destination $out }
$files64 = @('ClassicExplorer64.dll', 'ClassicIEDLL_64.dll', 'ClassicIE_64.exe', 'StartMenu.exe', 'StartMenuDLL.dll', 'StartMenuHelper64.dll')
foreach ($f in $files64) { Copy-Item -LiteralPath (Join-Path $bin "Setup64\$f") -Destination (Join-Path $out 'x64') }
if ($arm64) {
    New-Item -ItemType Directory -Path (Join-Path $out 'ARM64') -Force | Out-Null
    foreach ($f in $files64) { Copy-Item -LiteralPath (Join-Path $bin "SetupARM64\$f") -Destination (Join-Path $out 'ARM64') }
}
Copy-Item -Path (Join-Path $bin 'Skins\*.skin'), (Join-Path $bin 'Skins\*.skin7') -Destination $out
Copy-Item -LiteralPath (Join-Path $src 'Src\LICENSE.txt') -Destination $out
Publish-Build -From $out -Arch x86 -Version $ver -Note "Source: https://github.com/$repo, tag $tag (the installer's files, not an installer: see build.ps1)"
Complete-Build
