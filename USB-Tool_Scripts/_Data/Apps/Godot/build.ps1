param([string]$Version, [string]$WorkDir, [switch]$KeepWork, [switch]$Yes)
. "$PSScriptRoot\..\_Build-App.ps1"
trap { Stop-Build $_ }

# Builds the Godot editor from source (github.com/godotengine/godot) into Built\x64, Built\x86 and Built\ARM64, the
# way its Windows CI (.github/workflows/windows_builds.yml) does: SCons, target=editor production=yes, with the
# Direct3D 12 (Mesa NIR, Agility SDK, PIX), ANGLE, WinRT and AccessKit parts its install_*.py scripts download.
# Like the official zip: Godot_v<ver>-stable_win64.exe and its _console.exe (win32 / windows_arm64 for the others).
# x64 (and ARM64) use MSVC like the CI's editor job; x86 uses llvm-mingw (use_mingw=yes use_llvm=yes, one of the
# CI's other compilers), as MSVC 2022's 32-bit compiler crashes (C1001) on Godot's thirdparty astcenc code.
# Differences: the official builds are cross-compiled with MinGW on Linux (godot-build-scripts) with LTO; these have
# no LTO (MSVC: Godot's default; llvm-mingw: lto=none, to keep the link's memory use down). ARM64 is built only when
# Visual Studio has its ARM64 C++ tools (Microsoft.VisualStudio.Component.VC.Tools.ARM64).
# Needs: Visual Studio 2022 with C++; a portable Python, SCons (pip, in the work folder) and llvm-mingw, downloaded
# when missing
# Usage: build.cmd [-Version <x.y.z>] [-KeepWork] [-WorkDir <folder>]

$repo = 'godotengine/godot'
$tag = if ($Version) { ($Version -replace '-stable$') + '-stable' } else { Get-LatestGitHubTag $repo }
$ver = $tag -replace '-stable$'
$work = Start-Build -Name 'Godot' -NeedGB 16
$src = Join-Path $work 'src'
# (some test file names in the repo are too long for Windows' usual path limit)
$env:GIT_CONFIG_COUNT = '1'; $env:GIT_CONFIG_KEY_0 = 'core.longpaths'; $env:GIT_CONFIG_VALUE_0 = 'true'
Get-GitSource "https://github.com/$repo.git" $tag $src

# Python and SCons (the version Godot's CI uses), in a venv in the work folder
Use-Tool python -Version '3.9'
$venv = Join-Path $work 'venv'
Invoke-Checked python -m venv $venv
$py = Join-Path $venv 'Scripts\python.exe'
$sconsVer = '4.10.1'
$depsYml = Join-Path $src '.github\actions\godot-deps\action.yml'
if (Test-Path -LiteralPath $depsYml) {
    $m = [regex]::Match([IO.File]::ReadAllText($depsYml), 'scons-version:[\s\S]*?default:\s*([\d.]+)')
    if ($m.Success) { $sconsVer = $m.Groups[1].Value }
}
Invoke-Checked $py -m pip install --disable-pip-version-check -q "scons==$sconsVer"
$env:PYTHONIOENCODING = 'utf8'

# (the install_*.py scripts, and SCons, keep these parts in %LOCALAPPDATA%\Godot\build_deps; pointed at the work folder)
$env:LOCALAPPDATA = Join-Path $work 'deps'
Push-Location -LiteralPath $src
$opts = @()
try {
    foreach ($dep in @(@{ Script = 'install_d3d12_sdk_windows.py'; Opt = 'd3d12' }, @{ Script = 'install_angle.py'; Opt = 'angle' }, @{ Script = 'install_winrt.py'; Opt = 'winrt' }, @{ Script = 'install_accesskit.py'; Opt = 'accesskit' })) {
        if (-not (Test-Path -LiteralPath "misc\scripts\$($dep.Script)")) { continue }
        Say "Getting the build parts ($($dep.Script))..."
        & $py "misc\scripts\$($dep.Script)"
        if ($LASTEXITCODE -ne 0) { Say "($($dep.Script) failed, so building without $($dep.Opt))"; $opts += "$($dep.Opt)=no" }
        else { $opts += "$($dep.Opt)=yes" }
    }
}
finally { Pop-Location }

# llvm-mingw (for x86), the newest release from github.com/mstorsjo/llvm-mingw, in the tools folder
function Get-LlvmMingw {
    $found = Get-ChildItem -LiteralPath $script:toolsDir -Directory -Filter 'llvm-mingw-*-ucrt-x86_64' -ErrorAction SilentlyContinue | Sort-Object Name | Select-Object -Last 1
    if ($found -and (Test-Path -LiteralPath "$($found.FullName)\bin\i686-w64-mingw32-clang.exe")) { return $found.FullName }
    $rel = Get-Text 'https://api.github.com/repos/mstorsjo/llvm-mingw/releases/latest' | ConvertFrom-Json
    $asset = $rel.assets | Where-Object { $_.name -match '^llvm-mingw-\d+-ucrt-x86_64\.zip$' } | Select-Object -First 1
    if (-not $asset) { throw "Couldn't find llvm-mingw's x86_64 zip in its latest release" }
    Say "Getting llvm-mingw ($($rel.tag_name))..."
    $zip = Join-Path $script:toolsDir $asset.name
    Get-File $asset.browser_download_url $zip
    [IO.Compression.ZipFile]::ExtractToDirectory($zip, $script:toolsDir); Remove-Item -LiteralPath $zip
    return (Join-Path $script:toolsDir ($asset.name -replace '\.zip$'))
}

$env:PATH = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer;$env:PATH"
$cleanEnv = @{}; Get-ChildItem Env: | ForEach-Object { $cleanEnv[$_.Name] = $_.Value }
function Reset-Env { Get-ChildItem Env: | Where-Object { -not $cleanEnv.ContainsKey($_.Name) } | ForEach-Object { Remove-Item -LiteralPath "Env:$($_.Name)" }; foreach ($k in $cleanEnv.Keys) { Set-Item -LiteralPath "Env:$k" -Value $cleanEnv[$k] } }
function Test-VSComponent([string[]]$Components) {
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    return [bool](& $vswhere -version '[17.0,18.0)' -products * -requires $Components -property installationPath)
}

foreach ($arch in @(
        @{ VS = 'x64'; Scons = 'x86_64'; Folder = 'x64'; Name = 'win64' },
        @{ Scons = 'x86_32'; Folder = 'x86'; Name = 'win32'; Mingw = $true },
        @{ VS = 'arm64'; Scons = 'arm64'; Folder = 'ARM64'; Name = 'windows_arm64'; Needs = 'Microsoft.VisualStudio.Component.VC.Tools.ARM64' })) {
    if ($arch.Needs -and -not (Test-VSComponent $arch.Needs)) { Say "Skipping $($arch.Folder): Visual Studio 2022 doesn't have $($arch.Needs)"; continue }
    Reset-Env
    $sconsArgs = @('-m', 'SCons', 'platform=windows', 'target=editor', 'production=yes', "arch=$($arch.Scons)", 'debug_symbols=no', '-j4') + $opts
    if ($arch.Mingw) {
        $mingw = Get-LlvmMingw
        # (thirdparty\xatlas\xatlas.cpp uses realloc / qsort without <stdlib.h>, which newer libc++ no longer brings in)
        $sconsArgs += @('use_mingw=yes', 'use_llvm=yes', "mingw_prefix=$mingw", 'lto=none', 'ccflags=-include stdlib.h')
        $compiler = "llvm-mingw $(Split-Path -Leaf $mingw)"
    }
    else {
        Use-VisualStudio -Arch $arch.VS -Version '[17.0,18.0)' -Components (@('Microsoft.VisualStudio.Component.VC.Tools.x86.x64') + @($arch.Needs | Where-Object { $_ })) | Out-Null
        $compiler = 'MSVC'
    }
    Say "Building Godot $ver for $($arch.Folder) ($compiler)..."
    Push-Location -LiteralPath $src
    try {
        # (a compiler crash when memory is short is worth a second go; SCons carries on where it stopped)
        & $py @sconsArgs
        if ($LASTEXITCODE -ne 0) { Say 'SCons failed; trying once more (it carries on where it stopped)...'; Invoke-Checked $py @sconsArgs }
    }
    finally { Pop-Location }
    $out = Join-Path $work "out\$($arch.Folder)"
    New-Item -ItemType Directory -Path $out -Force | Out-Null
    # (godot.windows.editor.<arch>[.llvm].exe and its .console.exe)
    $built = @(Get-ChildItem -LiteralPath (Join-Path $src 'bin') -Filter "godot.windows.editor.$($arch.Scons)*.exe")
    $exe = $built | Where-Object { $_.Name -notmatch '\.console\.exe$' } | Select-Object -First 1
    $console = $built | Where-Object { $_.Name -match '\.console\.exe$' } | Select-Object -First 1
    if (-not $exe) { throw "The build didn't make bin\godot.windows.editor.$($arch.Scons).exe" }
    Copy-Item -LiteralPath $exe.FullName -Destination (Join-Path $out "Godot_v$ver-stable_$($arch.Name).exe")
    if ($console) { Copy-Item -LiteralPath $console.FullName -Destination (Join-Path $out "Godot_v$ver-stable_$($arch.Name)_console.exe") }
    Publish-Build -From $out -Arch $arch.Folder -Version $ver -Note "Source: https://github.com/$repo, tag $tag ($compiler, $($opts -join ' '))"
}
Complete-Build
