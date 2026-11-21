param([string]$Version, [string]$WorkDir, [switch]$KeepWork, [switch]$Yes)
. "$PSScriptRoot\..\_Build-App.ps1"
trap { Stop-Build $_ }

# Builds PuTTY from source (the release source archive from the.earth.li) into Built\x64, Built\x86 and
# Built\ARM64, the way its own build script (Buildscr) does: CMake, a static C runtime, the help file embedded,
# and the same files as the official putty.zip (putty, plink, pscp, psftp, puttygen, pageant + putty.chm)
# Differences: built with Visual Studio's cl (the official build uses clang-cl), and the help file (putty.chm) is
# the official one (building it needs Halibut)
# ARM64 is built only when Visual Studio has its ARM64 C++ tools (Microsoft.VisualStudio.Component.VC.Tools.ARM64)
# Needs: Visual Studio 2022 with the C++ tools, CMake (and Ninja: a portable copy is downloaded when missing)
# Usage: build.cmd [-Version <x.yy>] [-KeepWork] [-WorkDir <folder>]

if ($Version) { $ver = $Version -replace '^v' }
else {
    $page = Get-Text 'https://www.chiark.greenend.org.uk/~sgtatham/putty/latest.html'
    $m = [regex]::Match($page, 'putty-(\d+\.\d+)\.tar\.gz')
    if (-not $m.Success) { throw "Couldn't find the latest PuTTY version on its download page" }
    $ver = $m.Groups[1].Value
}
$work = Start-Build -Name 'PuTTY' -NeedGB 1
$base = "https://the.earth.li/~sgtatham/putty/$ver"
Say "Getting the PuTTY $ver source..."
Get-File "$base/putty-$ver.tar.gz" (Join-Path $work "putty-$ver.tar.gz")
Expand-Archive7 (Join-Path $work "putty-$ver.tar.gz") $work
$src = Join-Path $work "putty-$ver"
$chm = Join-Path $work 'putty.chm'
Get-File "$base/putty.chm" $chm

if (-not (Get-Command cmake.exe -ErrorAction SilentlyContinue)) { throw 'This build needs CMake (cmake.org) on the PATH' }
Use-Tool ninja

# (each architecture starts from the same environment, since Use-VisualStudio adds to it)
$cleanEnv = @{}; Get-ChildItem Env: | ForEach-Object { $cleanEnv[$_.Name] = $_.Value }
function Reset-Env { Get-ChildItem Env: | Where-Object { -not $cleanEnv.ContainsKey($_.Name) } | ForEach-Object { Remove-Item -LiteralPath "Env:$($_.Name)" }; foreach ($k in $cleanEnv.Keys) { Set-Item -LiteralPath "Env:$k" -Value $cleanEnv[$k] } }
function Test-VSComponent([string[]]$Components) {
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    return [bool](& $vswhere -version '[17.0,18.0)' -products * -requires $Components -property installationPath)
}

foreach ($arch in @(@{ VS = 'x64'; Folder = 'x64' }, @{ VS = 'x86'; Folder = 'x86' }, @{ VS = 'arm64'; Folder = 'ARM64'; Needs = 'Microsoft.VisualStudio.Component.VC.Tools.ARM64' })) {
    if ($arch.Needs -and -not (Test-VSComponent $arch.Needs)) { Say "Skipping $($arch.Folder): Visual Studio 2022 doesn't have $($arch.Needs)"; continue }
    Reset-Env
    $components = @('Microsoft.VisualStudio.Component.VC.Tools.x86.x64') + @($arch.Needs | Where-Object { $_ })
    Use-VisualStudio -Arch $arch.VS -Version '[17.0,18.0)' -Components $components | Out-Null
    Say "Building PuTTY $ver for $($arch.Folder)..."
    $build = Join-Path $work "build-$($arch.Folder)"
    Invoke-Checked cmake -S $src -B $build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded '-DCMAKE_C_FLAGS_RELEASE=/MT /O2' "-DPUTTY_EMBEDDED_CHM_FILE=$chm"
    Invoke-Checked cmake --build $build --parallel 4
    Copy-Item -LiteralPath $chm -Destination $build
    Publish-Build -From $build -Arch $arch.Folder -Version $ver -Files @('putty.exe', 'plink.exe', 'pscp.exe', 'psftp.exe', 'puttygen.exe', 'pageant.exe', 'putty.chm') -Note "Source: $base/putty-$ver.tar.gz (help file: $base/putty.chm)"
}
Complete-Build
