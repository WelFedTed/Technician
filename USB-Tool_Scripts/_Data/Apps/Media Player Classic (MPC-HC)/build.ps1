param([string]$Version, [string]$WorkDir, [switch]$KeepWork, [switch]$Yes)
. "$PSScriptRoot\..\_Build-App.ps1"
trap { Stop-Build $_ }

# Builds MPC-HC from source (github.com/clsid2/mpc-hc, with its LAV Filters / ffmpeg submodules) into Built\x64 and
# Built\x86, the way docs\Compilation.md says: Visual Studio (C++ with ATL and MFC), NASM, Python for the
# translations, then "build.bat Build Both MPCHC Release 7z", whose package step lays out the same folder as the
# official zip (mpc-hc64.exe / mpc-hc.exe, mpciconlib.dll, Lang\, LAVFilters64 / LAVFilters, Shaders, the DirectX
# DLLs, CrashReporter\, COPYING.txt).
# Differences: not signed; ffmpeg is compiled with cl unless Visual Studio has its Clang tools (optional).
# Needs: Visual Studio 2022 with C++, ATL and MFC (Microsoft.VisualStudio.Component.VC.ATLMFC), Git; NASM, Python
# and 7-Zip, downloaded into the tools folder when missing
# Usage: build.cmd [-Version <x.y.z>] [-KeepWork] [-WorkDir <folder>]

$repo = 'clsid2/mpc-hc'
$tag = if ($Version) { $Version } else { Get-LatestGitHubTag $repo }
$work = Start-Build -Name 'MPC-HC' -NeedGB 12
$src = Join-Path $work 'src'
# (a long path in the submodules' history needs git's long path support)
$env:GIT_CONFIG_COUNT = '1'; $env:GIT_CONFIG_KEY_0 = 'core.longpaths'; $env:GIT_CONFIG_VALUE_0 = 'true'

# Visual Studio first (with MFC), so a missing part is reported before the big download
$env:PATH = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer;$env:PATH"
$vs = Use-VisualStudio -Arch x64 -Version '[17.0,18.0)' -Components 'Microsoft.VisualStudio.Component.VC.Tools.x86.x64', 'Microsoft.VisualStudio.Component.VC.ATL', 'Microsoft.VisualStudio.Component.VC.ATLMFC'

Get-GitSource "https://github.com/$repo.git" $tag $src -Submodules

# NASM (the version Compilation.md names), from nasm.us
$doc = [IO.File]::ReadAllText((Join-Path $src 'docs\Compilation.md'))
$m = [regex]::Match($doc, 'releasebuilds/([\d.]+)/win64/nasm-[\d.]+-win64\.zip')
$nasmVer = if ($m.Success) { $m.Groups[1].Value } else { '2.16.03' }
$nasmDir = Join-Path $script:toolsDir "nasm-$nasmVer"
if (-not (Test-Path -LiteralPath "$nasmDir\nasm.exe")) {
    $zip = Join-Path $script:toolsDir "nasm-$nasmVer-win64.zip"
    Get-File "https://www.nasm.us/pub/nasm/releasebuilds/$nasmVer/win64/nasm-$nasmVer-win64.zip" $zip
    $tmp = Join-Path $script:toolsDir "nasm-$nasmVer-x"
    [IO.Compression.ZipFile]::ExtractToDirectory($zip, $tmp); Remove-Item -LiteralPath $zip
    Move-Item -LiteralPath (Get-ChildItem -LiteralPath $tmp -Directory | Select-Object -First 1).FullName -Destination $nasmDir
    Remove-Item -LiteralPath $tmp -Recurse -Force
}
Add-ToPath $nasmDir
# (Python builds the translation DLLs; 7-Zip makes the packages build.bat lays out)
Use-Tool python -Version '3.8'
$python = Split-Path -Parent (Get-Command python.exe).Source
Add-ToPath (Split-Path -Parent (Get-SevenZip))
$env:MSBUILDDISABLENODEREUSE = '1'

[IO.File]::WriteAllText((Join-Path $src 'build.user.bat'), "@ECHO OFF`r`nSET `"MPCHC_VS_PATH=$vs`"`r`nSET `"MPCHC_PYTHON=$python`"`r`n")
Say "Building MPC-HC $tag for x64 and x86..."
Push-Location -LiteralPath $src
try {
    & cmd.exe /d /c "build.bat Build Both MPCHC Release 7z"
    if ($LASTEXITCODE -ne 0) { throw "build.bat failed (exit code $LASTEXITCODE)" }
}
finally { Pop-Location }

foreach ($arch in 'x64', 'x86') {
    $pkg = Get-ChildItem -LiteralPath (Join-Path $src 'bin') -Filter "MPC-HC.*.$arch.7z" | Where-Object { $_.Name -notmatch '\.pdb\.7z$' } | Select-Object -First 1
    if (-not $pkg) { throw "build.bat didn't make bin\MPC-HC.*.$arch.7z" }
    $out = Join-Path $work "out\$arch"
    Expand-Archive7 $pkg.FullName $out
    $folder = Get-ChildItem -LiteralPath $out -Directory | Select-Object -First 1
    Publish-Build -From $folder.FullName -Arch $arch -Version $tag -Note "Source: https://github.com/$repo, tag $tag (build.bat, $($pkg.Name))"
}
Complete-Build
