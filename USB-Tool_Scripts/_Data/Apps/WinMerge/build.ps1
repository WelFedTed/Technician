param([string]$Version, [string]$WorkDir, [switch]$KeepWork, [switch]$Yes)
. "$PSScriptRoot\..\_Build-App.ps1"
trap { Stop-Build $_ }

# Builds WinMerge from source (github.com/WinMerge/winmerge, with its submodules) into Built\x64, Built\x86 and
# Built\ARM64, the way its CI workflow and BuildAll.cmd do: DownloadDeps.cmd, BuildTranslations.cmd, msbuild
# WinMerge.sln Release for each platform (as BuildBin.vs2022.cmd), then BuildArc.cmd's portable zip layout (the
# WinMerge folder of winmerge-<version>-<platform>-exe.zip)
# Like the official build, the parts that are separate projects come from their own releases, downloaded by
# DownloadDeps.cmd (Merge7z, Frhed, WinIMerge, WinWebDiff, darkmodelib, tree-sitter grammars, the shell extension,
# jq, tidy, md4c, patch). Not built: the help file (needs HTML Help Workshop) and the installers
# x86 uses the project's v141_xp toolset when Visual Studio has it (Microsoft.VisualStudio.Component.WinXP), otherwise
# v143; ARM64 is built only when Visual Studio has its ARM64 C++ tools and ARM64 MFC
# Needs: Visual Studio 2022 with the C++ tools and MFC (Microsoft.VisualStudio.Component.VC.ATLMFC)
# Usage: build.cmd [-Version <x.y.z>] [-KeepWork] [-WorkDir <folder>]

$repo = 'WinMerge/winmerge'
$tag = if ($Version) { 'v' + ($Version -replace '^v') } else { Get-LatestGitHubTag $repo }
$ver = $tag -replace '^v'
$work = Start-Build -Name 'WinMerge' -NeedGB 8
$src = Join-Path $work 'src'
# (some submodules have long paths, as the CI's "git config core.longpaths true" allows for)
$env:GIT_CONFIG_COUNT = '1'; $env:GIT_CONFIG_KEY_0 = 'core.longpaths'; $env:GIT_CONFIG_VALUE_0 = 'true'
Get-GitSource "https://github.com/$repo.git" $tag $src
# (the submodules, except tree-sitter-grammars: its grammars come prebuilt from DownloadDeps.cmd, and its many nested
# repos only add download time and very long paths)
$git = Get-Git
$modules = @(& $git -C $src config -f .gitmodules --get-regexp '^submodule\..*\.path$' | ForEach-Object { ($_ -split ' ', 2)[1] } | Where-Object { $_ -ne 'Externals/tree-sitter-grammars' })
Say "Getting the submodules ($($modules.Count))..."
Invoke-Checked $git -C $src submodule update --init --recursive --depth 1 -- @modules

function Test-VSComponent([string[]]$Components) {
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    return [bool](& $vswhere -version '[17.0,18.0)' -products * -requires $Components -property installationPath)
}
Use-VisualStudio -Arch x64 -Version '[17.0,18.0)' -Components @('Microsoft.VisualStudio.Component.VC.Tools.x86.x64', 'Microsoft.VisualStudio.Component.VC.ATLMFC') | Out-Null

# (the scripts call 7z: this PC's 7-Zip, or the standalone 7za as 7z.exe)
$sevenZip = Get-SevenZip
if ((Split-Path -Leaf $sevenZip) -ne '7z.exe') {
    $dir7 = Join-Path $work 'tools7z'
    New-Item -ItemType Directory -Path $dir7 -Force | Out-Null
    Copy-Item -Path (Join-Path (Split-Path -Parent $sevenZip) '*') -Destination $dir7
    Copy-Item -LiteralPath $sevenZip -Destination (Join-Path $dir7 '7z.exe')
    Add-ToPath $dir7
}
else { Add-ToPath (Split-Path -Parent $sevenZip) }

Push-Location -LiteralPath $src
try {
    Say 'Getting the prebuilt parts (DownloadDeps.cmd)...'
    & cmd.exe /d /c 'DownloadDeps.cmd < NUL'
    if ($LASTEXITCODE -ne 0) { throw "DownloadDeps.cmd failed (exit code $LASTEXITCODE)" }
    & cmd.exe /d /c 'BuildTranslations.cmd < NUL'
    if ($LASTEXITCODE -ne 0) { throw "BuildTranslations.cmd failed (exit code $LASTEXITCODE)" }
    # (Version.h, as BuildBin.cmd makes it)
    & cmd.exe /d /c 'call SetVersion.cmd && cscript //nologo ExpandEnvironmenStrings.js Version.in > Version.h'
    if ($LASTEXITCODE -ne 0) { throw "Couldn't make Version.h (exit code $LASTEXITCODE)" }
    # (BuildArc.cmd without its source and debug-symbol archives: just the zip's folder for a platform)
    $arc = [IO.File]::ReadAllLines((Join-Path $src 'BuildArc.cmd')) | Where-Object { $_ -notmatch '^\s*7z\.exe a -t7z' }
    [IO.File]::WriteAllLines((Join-Path $src 'BuildArcZip.cmd'), $arc)

    $xp = Test-VSComponent 'Microsoft.VisualStudio.Component.WinXP'
    foreach ($arch in @(@{ Platform = 'x64'; Folder = 'x64'; Zip = 'x64-' }, @{ Platform = 'x86'; Folder = 'x86'; Zip = '' }, @{ Platform = 'ARM64'; Folder = 'ARM64'; Zip = 'ARM64-'; Needs = @('Microsoft.VisualStudio.Component.VC.Tools.ARM64', 'Microsoft.VisualStudio.Component.VC.ATL.ARM64', 'Microsoft.VisualStudio.Component.VC.MFC.ARM64') })) {
        if ($arch.Needs -and -not (Test-VSComponent $arch.Needs)) { Say "Skipping $($arch.Folder): Visual Studio 2022 doesn't have $($arch.Needs -join ', ')"; continue }
        $toolset = @(); if ($arch.Platform -eq 'x86' -and -not $xp) { $toolset = @('/p:PlatformToolset=v143') }
        Say "Building WinMerge $ver for $($arch.Folder)..."
        Invoke-Checked msbuild WinMerge.sln /t:Rebuild /m:2 /p:CL_MPCount=2 /nologo /v:minimal /p:Configuration=Release "/p:Platform=$($arch.Platform)" @toolset
        & cmd.exe /d /c "BuildArcZip.cmd $($arch.Platform) < NUL"
        if ($LASTEXITCODE -ne 0) { throw "BuildArc.cmd $($arch.Platform) failed (exit code $LASTEXITCODE)" }
        Publish-Build -From (Join-Path $src "Build\Releases\$($arch.Zip)zip-version\WinMerge") -Arch $arch.Folder -Version $ver -Note "Source: https://github.com/$repo, tag $tag$(if ($toolset) { ' (v143 toolset)' })"
    }
}
finally { Pop-Location }
Complete-Build
