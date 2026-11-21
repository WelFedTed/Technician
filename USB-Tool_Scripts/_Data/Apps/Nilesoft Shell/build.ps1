param([string]$Version, [string]$WorkDir, [switch]$KeepWork, [switch]$Yes)
. "$PSScriptRoot\..\_Build-App.ps1"
trap { Stop-Build $_ }

# Builds Nilesoft Shell from source (github.com/moudey/Shell, with its plutosvg and Detours submodules) into
# Built\x64, Built\x86 and Built\ARM64: for each platform, the plutosvg and Detours libraries it links (they aren't in
# the repo, so they're built from the submodules with cl / nmake), then msbuild src\Shell.sln, release
# Each folder has what the official MSI installs: shell.exe, shell.dll, shell.nss and the imports folder. Not built:
# the MSI itself. Nilesoft Shell is a context menu extension: to use the build, register it from an elevated prompt
# with "shell.exe -register -restart" (and "shell.exe -unregister -restart" to remove it)
# The source gets one fix: a missing #include <chrono> in src\shared\System.h (current Visual Studio 2022 needs it)
# ARM64 is built only when Visual Studio has its ARM64 C++ tools (Microsoft.VisualStudio.Component.VC.Tools.ARM64)
# Needs: Visual Studio 2022 with the C++ tools
# Usage: build.cmd [-Version <x.y.z>] [-KeepWork] [-WorkDir <folder>]

$repo = 'moudey/Shell'
$tag = if ($Version) { 'v' + ($Version -replace '^v') } else { Get-LatestGitHubTag $repo }
$ver = $tag -replace '^v'
$work = Start-Build -Name 'Nilesoft Shell' -NeedGB 2
$src = Join-Path $work 'src'
# (the nested submodules can have long paths)
$env:GIT_CONFIG_COUNT = '1'; $env:GIT_CONFIG_KEY_0 = 'core.longpaths'; $env:GIT_CONFIG_VALUE_0 = 'true'
Get-GitSource "https://github.com/$repo.git" $tag $src -Submodules
# (System.h uses std::chrono without including <chrono>; newer Visual Studio headers no longer pull it in for it)
$systemH = Join-Path $src 'src\shared\System.h'
$text = [IO.File]::ReadAllText($systemH)
if ($text -notmatch '#include <chrono>') { [IO.File]::WriteAllText($systemH, $text.Replace('#include <thread>', "#include <thread>`r`n#include <chrono>")) }

function Test-VSComponent([string[]]$Components) {
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    return [bool](& $vswhere -version '[17.0,18.0)' -products * -requires $Components -property installationPath)
}

# (each architecture starts from the same environment, since Use-VisualStudio adds to it)
$cleanEnv = @{}; Get-ChildItem Env: | ForEach-Object { $cleanEnv[$_.Name] = $_.Value }
function Reset-Env { Get-ChildItem Env: | Where-Object { -not $cleanEnv.ContainsKey($_.Name) } | ForEach-Object { Remove-Item -LiteralPath "Env:$($_.Name)" }; foreach ($k in $cleanEnv.Keys) { Set-Item -LiteralPath "Env:$k" -Value $cleanEnv[$k] } }

$bin = Join-Path $src 'src\bin'
$libDir = Join-Path $src 'src\shared\Library'
$pluto = Join-Path $src 'src\lib\plutosvg'
foreach ($arch in @(@{ Platform = 'x64'; VS = 'x64'; Out = 'x64'; Lib = 'x64'; Detours = 'X64'; Folder = 'x64' }, @{ Platform = 'x86'; VS = 'x86'; Out = 'x86'; Lib = 'x86'; Detours = 'X86'; Folder = 'x86' }, @{ Platform = 'ARM64'; VS = 'arm64'; Out = 'arm64'; Lib = 'arm64'; Detours = 'ARM64'; Folder = 'ARM64'; Needs = 'Microsoft.VisualStudio.Component.VC.Tools.ARM64' })) {
    if ($arch.Needs -and -not (Test-VSComponent $arch.Needs)) { Say "Skipping $($arch.Folder): Visual Studio 2022 doesn't have $($arch.Needs)"; continue }
    Reset-Env
    Use-VisualStudio -Arch $arch.VS -Version '[17.0,18.0)' -Components (@('Microsoft.VisualStudio.Component.VC.Tools.x86.x64') + @($arch.Needs | Where-Object { $_ })) | Out-Null

    # (the projects link plutosvg-<arch>.lib and detours-<arch>.lib from src\shared\Library, which the repo doesn't
    # include: they're built here from the plutosvg and Detours submodules, with the static runtime the projects use)
    Say "Building plutosvg and Detours for $($arch.Folder)..."
    $obj = Join-Path $work "obj-plutosvg-$($arch.Folder)"
    New-Item -ItemType Directory -Path $obj -Force | Out-Null
    $cfiles = @(Get-Item -Path (Join-Path $pluto 'source\plutosvg.c'), (Join-Path $pluto 'plutovg\source\*.c'), (Join-Path $pluto 'plutovg\3rdparty\software\*.c') | ForEach-Object { $_.FullName })
    $includes = @('source', 'plutovg\include', 'plutovg\source', 'plutovg\3rdparty\software', 'plutovg\3rdparty\stb') | ForEach-Object { '/I' + (Join-Path $pluto $_) }
    # (32-bit: __stdcall by default, as the projects compile their Win32 release)
    $convention = @(); if ($arch.VS -eq 'x86') { $convention = @('/Gz') }
    Invoke-Checked cl /nologo /c /O2 /MT /DNDEBUG @convention "/Fo$obj\\" @includes @cfiles
    Invoke-Checked lib /nologo "/OUT:$libDir\plutosvg-$($arch.Lib).lib" (Get-ChildItem -LiteralPath $obj -Filter '*.obj' | ForEach-Object { $_.FullName })
    Push-Location -LiteralPath (Join-Path $src 'src\lib\detours\src')
    try { $env:DETOURS_TARGET_PROCESSOR = $arch.Detours; Invoke-Checked nmake /nologo }
    finally { Pop-Location; Remove-Item Env:DETOURS_TARGET_PROCESSOR -ErrorAction SilentlyContinue }
    Copy-Item -LiteralPath (Join-Path $src "src\lib\detours\lib.$($arch.Detours)\detours.lib") -Destination (Join-Path $libDir "detours-$($arch.Lib).lib")

    Say "Building Nilesoft Shell $ver for $($arch.Folder)..."
    Invoke-Checked msbuild (Join-Path $src 'src\Shell.sln') /m:2 /p:CL_MPCount=2 /nologo /v:minimal /p:Configuration=release "/p:Platform=$($arch.Platform)"
    $out = Join-Path $work "out\$($arch.Folder)"
    New-Item -ItemType Directory -Path $out -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $bin "release\$($arch.Out)\shell.exe"), (Join-Path $bin "release\$($arch.Out)\shell.dll"), (Join-Path $bin 'shell.nss') -Destination $out
    Copy-Item -LiteralPath (Join-Path $bin 'imports') -Destination $out -Recurse
    Copy-Item -LiteralPath (Join-Path $src 'LICENSE') -Destination (Join-Path $out 'LICENSE.txt')
    Publish-Build -From $out -Arch $arch.Folder -Version $ver -Note "Source: https://github.com/$repo, tag $tag (register with: shell.exe -register -restart, as admin)"
}
Complete-Build
