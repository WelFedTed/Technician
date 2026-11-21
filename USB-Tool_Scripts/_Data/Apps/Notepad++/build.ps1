param([string]$Version, [string]$WorkDir, [switch]$KeepWork, [switch]$Yes)
. "$PSScriptRoot\..\_Build-App.ps1"
trap { Stop-Build $_ }

# Builds Notepad++ from source (github.com/notepad-plus-plus/notepad-plus-plus) into Built\x64, Built\x86 and
# Built\ARM64, the way its CI workflow does (msbuild PowerEditor\visual.net\notepadPlus.sln, Release, with Scintilla
# and Lexilla), laid out like the official portable zip (PowerEditor\installer\packageAll.bat): notepad++.exe with
# its model xml files, localization, themes, autoCompletion, functionList and userDefineLangs
# Differences: no plugins (NppExport, mimeTools, NppConverter), Plugins Admin (nppPluginList.dll) or updater (GUP):
# those are separate projects whose binaries the release copies in
# ARM64 is built only when Visual Studio has its ARM64 C++ tools (Microsoft.VisualStudio.Component.VC.Tools.ARM64)
# Needs: Visual Studio 2022 with the C++ tools
# Usage: build.cmd [-Version <x.y.z>] [-KeepWork] [-WorkDir <folder>]

$repo = 'notepad-plus-plus/notepad-plus-plus'
$tag = if ($Version) { 'v' + ($Version -replace '^v') } else { Get-LatestGitHubTag $repo }
$work = Start-Build -Name 'Notepad++' -NeedGB 2
$src = Join-Path $work 'src'
Get-GitSource "https://github.com/$repo.git" $tag $src

function Test-VSComponent([string[]]$Components) {
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    return [bool](& $vswhere -version '[17.0,18.0)' -products * -requires $Components -property installationPath)
}

$pe = Join-Path $src 'PowerEditor'
$inst = Join-Path $pe 'installer'
Use-VisualStudio -Arch x64 -Version '[17.0,18.0)' | Out-Null
foreach ($arch in @(@{ Platform = 'x64'; Bin = 'bin64'; Folder = 'x64' }, @{ Platform = 'Win32'; Bin = 'bin'; Folder = 'x86' }, @{ Platform = 'ARM64'; Bin = 'binarm64'; Folder = 'ARM64'; Needs = 'Microsoft.VisualStudio.Component.VC.Tools.ARM64' })) {
    if ($arch.Needs -and -not (Test-VSComponent $arch.Needs)) { Say "Skipping $($arch.Folder): Visual Studio 2022 doesn't have $($arch.Needs)"; continue }
    Say "Building Notepad++ $tag for $($arch.Folder)..."
    Push-Location -LiteralPath (Join-Path $pe 'visual.net')
    try { Invoke-Checked msbuild notepadPlus.sln /m:2 /p:CL_MPCount=2 /nologo /v:minimal /p:Configuration=Release "/p:Platform=$($arch.Platform)" }
    finally { Pop-Location }

    # (the portable zip's layout, as packageAll.bat makes it)
    $out = Join-Path $work "out\$($arch.Folder)"
    foreach ($d in 'localization', 'themes', 'autoCompletion', 'functionList', 'userDefineLangs') { New-Item -ItemType Directory -Path (Join-Path $out $d) -Force | Out-Null }
    Copy-Item -LiteralPath (Join-Path $src 'LICENSE') -Destination (Join-Path $out 'license.txt')
    Copy-Item -LiteralPath (Join-Path $pe 'bin\readme.txt'), (Join-Path $pe 'bin\change.log') -Destination $out
    foreach ($f in 'langs.model.xml', 'stylers.model.xml', 'tabContextMenu_example.xml', 'toolbarButtonsConf_example.xml') { Copy-Item -LiteralPath (Join-Path $pe "src\$f") -Destination $out }
    Copy-Item -LiteralPath (Join-Path $inst 'xml4Config\doLocalConf.xml'), (Join-Path $inst 'xml4Config\disableNppAutoUpdate.xml') -Destination $out
    Copy-Item -LiteralPath (Join-Path $pe "$($arch.Bin)\notepad++.exe") -Destination $out
    Copy-Item -Path (Join-Path $inst 'nativeLang\*.xml') -Destination (Join-Path $out 'localization')
    Copy-Item -Path (Join-Path $inst 'APIs\*.xml') -Destination (Join-Path $out 'autoCompletion')
    Copy-Item -Path (Join-Path $inst 'functionList\*.xml') -Destination (Join-Path $out 'functionList')
    Copy-Item -Path (Join-Path $pe 'bin\userDefineLangs\markdown._preinstalled*.udl.xml') -Destination (Join-Path $out 'userDefineLangs')
    Copy-Item -Path (Join-Path $inst 'themes\*.xml') -Destination (Join-Path $out 'themes')
    Publish-Build -From $out -Arch $arch.Folder -Version ($tag -replace '^v') -Note "Source: https://github.com/$repo, tag $tag (no plugins or updater: see build.ps1)"
}
Complete-Build
