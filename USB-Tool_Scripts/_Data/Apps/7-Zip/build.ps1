param([string]$Version, [string]$WorkDir, [switch]$KeepWork, [switch]$Yes)
. "$PSScriptRoot\..\_Build-App.ps1"
trap { Stop-Build $_ }

# Builds 7-Zip from source (github.com/ip7z/7zip) into Built\x86, Built\x64 and Built\ARM64, the way its readme
# (DOC\readme.txt) says the release binaries are built: nmake with the makefiles in CPP\7zip, for each platform
# (only in the projects of the files below, not the Far plugin, 7zFM's standalone bundle, 7zz, ...)
# Each Built\<arch> has the installed 7-Zip's programs (7z.exe, 7z.dll, 7zFM.exe, 7zG.exe, 7-zip.dll, 7z.sfx,
# 7zCon.sfx; x64 also 7-zip32.dll, the 32-bit shell extension) and the command line ones from 7-Zip Extra
# (7za.exe, 7za.dll, 7zxa.dll) and 7zr.exe, with License.txt
# Differences: no Lang folder, help file (7-zip.chm) or History.txt (they aren't in the source)
# ARM64 is built only when Visual Studio has its ARM64 C++ tools (Microsoft.VisualStudio.Component.VC.Tools.ARM64)
# Needs: Visual Studio 2022 with the C++ tools (nmake, ml / ml64)
# Usage: build.cmd [-Version <yy.mm>] [-KeepWork] [-WorkDir <folder>]

$repo = 'ip7z/7zip'
$tag = if ($Version) { $Version -replace '^v' } else { Get-LatestGitHubTag $repo }
$work = Start-Build -Name '7-Zip' -NeedGB 2
$src = Join-Path $work 'src'
Get-GitSource "https://github.com/$repo.git" $tag $src

# (each architecture starts from the same environment, since Use-VisualStudio adds to it)
$cleanEnv = @{}; Get-ChildItem Env: | ForEach-Object { $cleanEnv[$_.Name] = $_.Value }
function Reset-Env { Get-ChildItem Env: | Where-Object { -not $cleanEnv.ContainsKey($_.Name) } | ForEach-Object { Remove-Item -LiteralPath "Env:$($_.Name)" }; foreach ($k in $cleanEnv.Keys) { Set-Item -LiteralPath "Env:$k" -Value $cleanEnv[$k] } }
function Test-VSComponent([string[]]$Components) {
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    return [bool](& $vswhere -version '[17.0,18.0)' -products * -requires $Components -property installationPath)
}

# (project folder under CPP\7zip -> the file it makes)
$files = [ordered]@{
    'UI\Console' = '7z.exe'; 'UI\GUI' = '7zG.exe'; 'UI\FileManager' = '7zFM.exe'; 'UI\Explorer' = '7-zip.dll'
    'Bundles\Format7zF' = '7z.dll'; 'Bundles\SFXWin' = '7z.sfx'; 'Bundles\SFXCon' = '7zCon.sfx'
    'Bundles\Alone' = '7za.exe'; 'Bundles\Format7z' = '7za.dll'; 'Bundles\Format7zExtract' = '7zxa.dll'; 'Bundles\Alone7z' = '7zr.exe'
}
foreach ($arch in @(@{ VS = 'x86'; Folder = 'x86' }, @{ VS = 'x64'; Folder = 'x64' }, @{ VS = 'arm64'; Folder = 'ARM64'; Needs = 'Microsoft.VisualStudio.Component.VC.Tools.ARM64' })) {
    if ($arch.Needs -and -not (Test-VSComponent $arch.Needs)) { Say "Skipping $($arch.Folder): Visual Studio 2022 doesn't have $($arch.Needs)"; continue }
    Reset-Env
    $components = @('Microsoft.VisualStudio.Component.VC.Tools.x86.x64') + @($arch.Needs | Where-Object { $_ })
    Use-VisualStudio -Arch $arch.VS -Version '[17.0,18.0)' -Components $components | Out-Null
    # (the makefiles compile with -MP<number of processors>, so this keeps it to 4 at a time)
    $env:NUMBER_OF_PROCESSORS = '4'
    Say "Building 7-Zip $tag for $($arch.Folder)..."
    # (nmake in each project these files come from: the same as nmake in CPP\7zip, without the ones not needed here)
    foreach ($project in $files.Keys) {
        Push-Location -LiteralPath (Join-Path $src "CPP\7zip\$project")
        try { Invoke-Checked nmake -nologo "PLATFORM=$($arch.VS)" }
        finally { Pop-Location }
    }
    $out = Join-Path $work "out\$($arch.Folder)"
    New-Item -ItemType Directory -Path $out -Force | Out-Null
    foreach ($project in $files.Keys) { Copy-Item -LiteralPath (Join-Path $src "CPP\7zip\$project\$($arch.VS)\$($files[$project])") -Destination $out }
    # (the x64 7-Zip comes with the 32-bit shell extension too, for 32-bit programs' file dialogs)
    if ($arch.Folder -eq 'x64' -and (Test-Path -LiteralPath (Join-Path $work 'out\x86\7-zip.dll'))) { Copy-Item -LiteralPath (Join-Path $work 'out\x86\7-zip.dll') -Destination (Join-Path $out '7-zip32.dll') }
    Copy-Item -LiteralPath (Join-Path $src 'DOC\License.txt') -Destination $out
    Publish-Build -From $out -Arch $arch.Folder -Version $tag -Note "Source: https://github.com/$repo, tag $tag"
}
Complete-Build
