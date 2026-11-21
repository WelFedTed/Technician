param([string]$Version, [string]$WorkDir, [switch]$KeepWork, [switch]$Yes)
. "$PSScriptRoot\..\_Build-App.ps1"
trap { Stop-Build $_ }

# Builds Windhawk's own programs from source (github.com/ramensoftware/windhawk, src\windhawk) into Built\x86, the
# way its src\windhawk\build.bat does (MSBuild windhawk.sln, Release: the app for Win32, the engine for Win32, x64
# and ARM64): windhawk.exe and Engine\32, Engine\64 and Engine\arm64\windhawk.dll, laid out like an installed
# Windhawk. The rest of what windhawk_setup.exe installs isn't in this source: the UI (VSCodium with the Windhawk
# extension) and the mod compiler (LLVM MinGW). As the README says, these files are for replacing the ones in a
# portable Windhawk made by the official installer.
# Needs: Visual Studio 2022 with the C++ tools, ATL (the app uses WTL) and the ARM64 C++ tools (the ARM64 engine)
# Usage: build.cmd [-Version <x.y.z>] [-KeepWork] [-WorkDir <folder>]

$repo = 'ramensoftware/windhawk'
$tag = if ($Version) { 'v' + ($Version -replace '^v') } else { Get-LatestGitHubTag $repo }
$work = Start-Build -Name 'Windhawk' -NeedGB 2
$src = Join-Path $work 'src'
Get-GitSource "https://github.com/$repo.git" $tag $src

Use-VisualStudio -Arch x64 -Version '[17.0,18.0)' -Components 'Microsoft.VisualStudio.Component.VC.Tools.x86.x64', 'Microsoft.VisualStudio.Component.VC.ATL', 'Microsoft.VisualStudio.Component.VC.Tools.ARM64' | Out-Null

$sln = Join-Path $src 'src\windhawk\windhawk.sln'
# (the app's WTL comes from NuGet, through packages.config)
Say 'Restoring NuGet packages (WTL)...'
Invoke-Checked msbuild.exe $sln /nologo /t:restore /p:RestorePackagesConfig=true /p:Configuration=Release /p:Platform=Win32
foreach ($step in @(@{ Target = 'app'; Platform = 'Win32' }, @{ Target = 'engine'; Platform = 'Win32' }, @{ Target = 'engine'; Platform = 'x64' }, @{ Target = 'engine'; Platform = 'ARM64' })) {
    Say "Building the $($step.Target) for $($step.Platform)..."
    Invoke-Checked msbuild.exe $sln /nologo /m:4 "/t:$($step.Target)" /p:Configuration=Release "/p:Platform=$($step.Platform)"
}

# (installed Windhawk: windhawk.exe, and the engine in Engine\<version>\32|64|arm64; the version folder is left out,
# since it's named after the release)
$rel = Join-Path $src 'src\windhawk\Release'
$out = Join-Path $work 'out'
$appExe = Get-ChildItem -LiteralPath $rel -Filter 'windhawk.exe' -Recurse | Select-Object -First 1
if (-not $appExe) { throw "The build didn't make windhawk.exe" }
New-Item -ItemType Directory -Path $out -Force | Out-Null
Copy-Item -LiteralPath $appExe.FullName -Destination $out
foreach ($bits in '32', '64', 'arm64') {
    $dll = Join-Path $rel "$bits\windhawk.dll"
    if (-not (Test-Path -LiteralPath $dll)) { throw "The build didn't make Release\$bits\windhawk.dll" }
    New-Item -ItemType Directory -Path (Join-Path $out "Engine\$bits") -Force | Out-Null
    Copy-Item -LiteralPath $dll -Destination (Join-Path $out "Engine\$bits")
}
Publish-Build -From $out -Arch 'x86' -Version ($tag -replace '^v') -Note "Source: https://github.com/$repo, tag $tag (windhawk.exe and the engine only; no UI or compiler)"
Complete-Build
