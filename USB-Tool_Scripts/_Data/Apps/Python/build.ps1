param([string]$Version, [string]$WorkDir, [switch]$KeepWork, [switch]$Yes)
. "$PSScriptRoot\..\_Build-App.ps1"
trap { Stop-Build $_ }

# Builds Python (CPython) from source (github.com/python/cpython) into Built\x64, Built\x86 and Built\ARM64:
# PCbuild\build.bat -e (which gets its own externals: OpenSSL, SQLite, Tcl/Tk, libffi, ...) for each platform, then
# the PC\layout script makes the same kind of folder as the official python-<version>-<arch>.zip (the Python install
# manager's package: python.exe, pythonw.exe, DLLs, Lib, libs, include, tcl, pip, venv, idle, __install__.json)
# Differences: not PGO-optimized (the official build runs a profiling pass, so it's a little faster), no HTML
# documentation (needs Sphinx), not signed
# ARM64 is built only when Visual Studio has its ARM64 C++ tools (Microsoft.VisualStudio.Component.VC.Tools.ARM64)
# Needs: Visual Studio 2022 with the C++ tools (build.bat downloads a Python for the build itself when needed)
# Usage: build.cmd [-Version <3.x.y>] [-KeepWork] [-WorkDir <folder>]

if ($Version) { $ver = $Version -replace '^v' }
else {
    # (the version update.cmd downloads: python.org's latest Python 3 release)
    $page = Get-Text 'https://www.python.org/downloads/windows/'
    $m = [regex]::Match($page, 'Latest Python 3 Release - Python ([\d.]+)')
    if (-not $m.Success) { throw "Couldn't find the latest Python version on python.org" }
    $ver = $m.Groups[1].Value
}
$tag = "v$ver"
$work = Start-Build -Name 'Python' -NeedGB 8
$src = Join-Path $work 'src'
Get-GitSource 'https://github.com/python/cpython.git' $tag $src

function Test-VSComponent([string[]]$Components) {
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    return [bool](& $vswhere -version '[17.0,18.0)' -products * -requires $Components -property installationPath)
}
Use-VisualStudio -Arch x64 -Version '[17.0,18.0)' | Out-Null

# (x64 first: its python.exe then runs the layout script for the others too)
$hostPython = Join-Path $src 'PCbuild\amd64\python.exe'
$layoutOptions = @('--include-stable', '--include-pip', '--include-tcltk', '--include-idle', '--include-venv', '--include-dev', '--include-alias', '--include-install-json', '--include-builddetails-json')
foreach ($arch in @(@{ Platform = 'x64'; Dir = 'amd64'; Folder = 'x64' }, @{ Platform = 'Win32'; Dir = 'win32'; Folder = 'x86' }, @{ Platform = 'ARM64'; Dir = 'arm64'; Folder = 'ARM64'; Needs = 'Microsoft.VisualStudio.Component.VC.Tools.ARM64' })) {
    if ($arch.Needs -and -not (Test-VSComponent $arch.Needs)) { Say "Skipping $($arch.Folder): Visual Studio 2022 doesn't have $($arch.Needs)"; continue }
    Say "Building Python $ver for $($arch.Folder)..."
    # (-M then /m:4: 4 projects at a time instead of one per processor)
    & cmd.exe /d /c "`"$(Join-Path $src 'PCbuild\build.bat')`" -e -p $($arch.Platform) -M /m:4 < NUL"
    if ($LASTEXITCODE -ne 0) { throw "PCbuild\build.bat -p $($arch.Platform) failed (exit code $LASTEXITCODE)" }
    $out = Join-Path $work "out\$($arch.Folder)"
    Say "Laying out Python $ver for $($arch.Folder)..."
    Invoke-Checked $hostPython (Join-Path $src 'PC\layout') -s $src -b (Join-Path $src "PCbuild\$($arch.Dir)") --arch $arch.Dir -t (Join-Path $work "layout-$($arch.Folder)") --copy $out @layoutOptions
    Publish-Build -From $out -Arch $arch.Folder -Version $ver -Note "Source: https://github.com/python/cpython, tag $tag (no PGO, no HTML docs)"
}
Complete-Build
