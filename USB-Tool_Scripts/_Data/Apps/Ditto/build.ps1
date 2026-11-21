param([string]$Version, [string]$WorkDir, [switch]$KeepWork, [switch]$Yes)
. "$PSScriptRoot\..\_Build-App.ps1"
trap { Stop-Build $_ }

# Builds Ditto from source (github.com/sabrogden/Ditto) into Built\x64, the way its release workflow does (NuGet
# restore, msbuild CP_Main_10.sln Release|x64, rcedit sets the version), laid out like the portable zip
# (DittoSetup\BuildPortableZIP.bat): Ditto.exe, ICU_Loader.dll, Addins, Language, Themes, the "portable" marker and the
# Visual C++ / MFC runtime DLLs (from Visual Studio's redistributable folder)
# Needs: Visual Studio 2022 with the C++ tools and MFC (Microsoft.VisualStudio.Component.VC.ATLMFC); NuGet (nuget.exe
#        is downloaded into the tools folder)
# Usage: build.cmd [-Version <x.y.z.w>] [-KeepWork] [-WorkDir <folder>]

$repo = 'sabrogden/Ditto'
$tag = if ($Version) { $Version -replace '^v' } else { Get-LatestGitHubTag $repo }
$work = Start-Build -Name 'Ditto' -NeedGB 2
$src = Join-Path $work 'src'
Get-GitSource "https://github.com/$repo.git" $tag $src

$nuget = Join-Path $script:toolsDir 'nuget\nuget.exe'
if (-not (Test-Path -LiteralPath $nuget)) { Say 'Getting nuget.exe...'; Get-File 'https://dist.nuget.org/win-x86-commandline/latest/nuget.exe' $nuget }

Use-VisualStudio -Arch x64 -Version '[17.0,18.0)' -Components @('Microsoft.VisualStudio.Component.VC.Tools.x86.x64', 'Microsoft.VisualStudio.Component.VC.ATLMFC') | Out-Null
$sln = Join-Path $src 'CP_Main_10.sln'
# (from nuget.org, with NuGet's package cache in the tools folder instead of the user's profile)
$env:NUGET_PACKAGES = Join-Path $script:toolsDir 'nuget\packages'
Invoke-Checked $nuget restore $sln -NonInteractive -Source https://api.nuget.org/v3/index.json
Say "Building Ditto $tag for x64..."
Invoke-Checked msbuild $sln /m:2 /p:CL_MPCount=2 /nologo /v:minimal /p:Configuration=Release /p:Platform=x64
$rel = Join-Path $src 'Release64'
Invoke-Checked (Join-Path $src 'DittoSetup\rcedit-x64.exe') (Join-Path $rel 'Ditto.exe') --set-file-version $tag --set-product-version $tag

# (the portable zip's layout, as BuildPortableZIP.bat makes it)
$out = Join-Path $work 'out\x64'
foreach ($d in 'Help', 'Language', 'Themes', 'Addins') { New-Item -ItemType Directory -Path (Join-Path $out $d) -Force | Out-Null }
Copy-Item -LiteralPath (Join-Path $rel 'Ditto.exe'), (Join-Path $rel 'ICU_Loader.dll') -Destination $out
Copy-Item -Path (Join-Path $rel 'Addins\*.dll') -Destination (Join-Path $out 'Addins')
Copy-Item -LiteralPath (Join-Path $src 'DittoSetup\portable') -Destination $out
Copy-Item -Path (Join-Path $src 'Debug\language\*.xml') -Destination (Join-Path $out 'Language')
Copy-Item -Path (Join-Path $src 'Debug\themes\*.xml') -Destination (Join-Path $out 'Themes')
# (the runtime DLLs, from Visual Studio's redistributable files instead of the PC's System32)
$redist = Get-ChildItem -Path (Join-Path $env:VCToolsRedistDir 'x64') -Directory | Where-Object { $_.Name -match '^Microsoft\.VC\d+\.(CRT|MFC)$' }
foreach ($f in 'vcruntime140.dll', 'vcruntime140_1.dll', 'msvcp140.dll', 'mfc140u.dll') {
    $dll = $redist | ForEach-Object { Join-Path $_.FullName $f } | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if (-not $dll) { throw "Couldn't find $f in $env:VCToolsRedistDir" }
    Copy-Item -LiteralPath $dll -Destination $out
}
Publish-Build -From $out -Arch x64 -Version $tag -Note "Source: https://github.com/$repo, tag $tag"
Complete-Build
