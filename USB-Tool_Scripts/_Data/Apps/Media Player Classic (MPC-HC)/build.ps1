param([string]$Version, [string]$WorkDir, [switch]$KeepWork, [switch]$Yes)
. "$PSScriptRoot\..\_Build-App.ps1"
trap { Stop-Build $_ }

# Builds MPC-HC from source (github.com/clsid2/mpc-hc, with its LAV Filters / ffmpeg submodules) into Built\x64 and
# Built\x86, the way docs\Compilation.md says: Visual Studio (C++ with ATL and MFC), NASM, Python for the
# translations, then "build.bat Build Both MPCHC Release 7z", whose package step lays out the same folder as the
# official zip (mpc-hc64.exe / mpc-hc.exe, mpciconlib.dll, Lang\, LAVFilters64 / LAVFilters, Shaders, the DirectX
# DLLs, CrashReporter\, COPYING.txt).
# LAV Filters' ffmpeg is built with its MSVC projects (clang-cl when Visual Studio has its Clang tools, else cl),
# or, when a release's MSVC projects are out of date for its ffmpeg (as 2.8.5's are), with MinGW-w64 GCC from a
# portable MSYS2 (Compilation.md, Part H). Differences: not signed.
# Needs: Visual Studio 2022 with C++, ATL and MFC (Microsoft.VisualStudio.Component.VC.ATLMFC), Git; NASM, Python,
# 7-Zip and (only when needed) MSYS2 with MinGW-w64 GCC, downloaded into the tools folder when missing
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
# (with polib, which the translations need (Compilation.md, Part F), in a venv in the tools folder)
$pyVenv = Join-Path $script:toolsDir 'mpchc-python-venv'
if (-not (Test-Path -LiteralPath (Join-Path $pyVenv 'Lib\site-packages\polib.py'))) {
    Say 'Getting polib (for the translations)...'
    Invoke-Checked python -m venv $pyVenv
    Invoke-Checked (Join-Path $pyVenv 'Scripts\python.exe') -m pip install --disable-pip-version-check -q polib
}
$python = Join-Path $pyVenv 'Scripts'
Add-ToPath (Split-Path -Parent (Get-SevenZip))
$env:MSBUILDDISABLENODEREUSE = '1'

# (build.bat runs MSBuild with /maxcpucount, one project per core: limited to 4 at once, with cl's /MP at one each,
# so the build doesn't take over the PC, and without leaving MSBuild nodes running that keep files locked)
$buildBat = Join-Path $src 'build.bat'
foreach ($bat in $buildBat, (Join-Path $src 'src\thirdparty\LAVFilters\build_lavfilters.bat')) {
    $batText = [IO.File]::ReadAllText($bat)
    $batText = $batText.Replace('/maxcpucount ', '/maxcpucount:4 ').Replace(' /m ', ' /m:4 ').Replace('/nodeReuse:true', '/nodeReuse:false')
    [IO.File]::WriteAllText($bat, $batText)
}
$env:CL_MPCount = '1'
# (build.bat and the batch files it calls run each other from the current folder, which cmd skips when the
# NoDefaultCurrentDirectoryInExePath setting is on, as in some terminals and agents)
Remove-Item Env:NoDefaultCurrentDirectoryInExePath -ErrorAction SilentlyContinue

# LAV Filters' ffmpeg: with its MSVC projects (msvc\ffmpeg, the default) when they were generated for the ffmpeg
# that's checked out; a release can be tagged before they're regenerated after a LAV Filters update (2.8.5 was:
# their file lists miss new ffmpeg sources, so it doesn't link), and then with MinGW-w64 GCC from a portable MSYS2,
# as LAV Filters upstream builds it (Compilation.md, Part H; its static libraries come with LAV's source)
$lav = Join-Path $src 'src\thirdparty\LAVFilters'
$ffVersion = [IO.File]::ReadAllText((Join-Path $lav 'msvc\ffmpeg\cl\generated\x64\libavutil\ffversion.h'))
$ffHead = (& (Get-Git) -C (Join-Path $lav 'src\ffmpeg') rev-parse HEAD | Out-String).Trim()
$genHash = [regex]::Match($ffVersion, 'FFMPEG_VERSION "[^"]*-g([0-9a-f]{7,})"').Groups[1].Value
$userBat = ''
if ($genHash -and $ffHead -and -not $ffHead.StartsWith($genHash)) {
    Say "LAV Filters' MSVC ffmpeg projects are for ffmpeg $genHash, not the checked-out $($ffHead.Substring(0, 10)): building ffmpeg with MinGW-w64 GCC"
    Use-Msys2 -Packages 'make', 'pkg-config', 'diffutils', 'mingw-w64-i686-gcc', 'mingw-w64-x86_64-gcc'
    $mingw64 = Join-Path $script:msysDir 'mingw64\bin'
    # (build_ffmpeg.sh cross-compiles x64 with the x86_64-w64-mingw32- tools, as in the toolchain LAV uses; MSYS2's
    # mingw64 has the prefixed gcc but not prefixed binutils, so copies with those names are made beside them)
    foreach ($tool in 'ar', 'nm', 'ranlib', 'strip', 'windres', 'objcopy', 'objdump', 'dlltool', 'ld', 'as') {
        $prefixed = Join-Path $mingw64 "x86_64-w64-mingw32-$tool.exe"
        if (-not (Test-Path -LiteralPath $prefixed) -and (Test-Path -LiteralPath (Join-Path $mingw64 "$tool.exe"))) { Copy-Item -LiteralPath (Join-Path $mingw64 "$tool.exe") -Destination $prefixed }
    }
    # (LAV's own toolchain links its runtime statically; MSYS2's gcc would make the ffmpeg DLLs need its
    # libgcc_s, libwinpthread and libz DLLs, so the link is made static, as in the official DLLs)
    $ffSh = Join-Path $lav 'build_ffmpeg.sh'
    $shText = [IO.File]::ReadAllText($ffSh)
    $shText = $shText.Replace('EXTRA_LDFLAGS="${EXTRA_LDFLAGS} -L../../../thirdparty/64/lib"', 'EXTRA_LDFLAGS="${EXTRA_LDFLAGS} -L../../../thirdparty/64/lib -static"')
    $shText = $shText.Replace('EXTRA_LDFLAGS="${EXTRA_LDFLAGS} -L../../../thirdparty/32/lib"', 'EXTRA_LDFLAGS="${EXTRA_LDFLAGS} -L../../../thirdparty/32/lib -static"')
    if ($shText -notmatch 'thirdparty/64/lib -static"' -or $shText -notmatch 'thirdparty/32/lib -static"') { throw "Couldn't add -static to build_ffmpeg.sh's GCC link options" }
    [IO.File]::WriteAllText($ffSh, $shText)
    # (common.bat puts MSYS2 and mingw32 first on the PATH; mingw64 after them, for the prefixed x64 tools)
    $env:PATH = "$env:PATH;$mingw64"
    $userBat = "SET `"MPCHC_MSYS=$($script:msysDir)`"`r`nSET `"MPCHC_MINGW32=$($script:msysDir)\mingw32`"`r`nSET `"MPCHC_MINGW64=$($script:msysDir)\mingw64`"`r`nSET `"MPCHC_LAV_TOOLCHAIN=GCC`"`r`nSET `"MPCHC_LAV_JOBS=4`"`r`n"
}

# (build.bat passes MPCHC_WINSDK_VER to vsdevcmd -winsdk=, and unless build.user.bat sets it, it's the 8.1 that
# include\mpc-hc_config.h names, which isn't installed: the Windows SDK that Use-VisualStudio found)
$winSdk = "$env:WindowsSDKVersion".TrimEnd('\')
if (-not $winSdk) { throw "Visual Studio's build environment didn't name a Windows SDK (WindowsSDKVersion)" }
[IO.File]::WriteAllText((Join-Path $src 'build.user.bat'), "@ECHO OFF`r`nSET `"MPCHC_VS_PATH=$vs`"`r`nSET `"MPCHC_PYTHON=$python`"`r`nSET `"MPCHC_WINSDK_VER=$winSdk`"`r`n$userBat")
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
