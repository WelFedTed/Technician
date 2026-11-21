param([string]$Version, [string]$WorkDir, [switch]$KeepWork, [switch]$Yes)
. "$PSScriptRoot\..\_Build-App.ps1"
trap { Stop-Build $_ }

# Builds Node.js from source (the release tarball from nodejs.org/dist, github.com/nodejs/node) into Built\x64, like
# the node-v<version>-win-x64.zip update.cmd downloads: node.exe, npm / npx / corepack and their node_modules,
# nodevars.bat, install_tools.bat, LICENSE, README.md and CHANGELOG.md. It runs the project's own Windows build,
# vcbuild.bat (BUILDING.md, "Windows"): "vcbuild release x64 package" - ClangCL (required since Node.js 24),
# NASM for OpenSSL's assembly, Rust for Temporal (Node.js 26 and newer), Python for gyp.
# ARM64 is built only when Visual Studio has its ARM64 C++ tools. No MSI (that needs WiX and the .NET SDK part).
# Needs: Visual Studio 2022 (17.14) or 2026 with C++ and its Clang parts (Microsoft.VisualStudio.Component.VC.Llvm.Clang,
#        Microsoft.VisualStudio.Component.VC.Llvm.ClangToolset); Python, NASM and Rust are downloaded into the tools
#        folder when missing. A long build (an hour or more), about 15 GB.
# Usage: build.cmd [-Version <x.y.z>] [-KeepWork] [-WorkDir <folder>]

# (the newest release, as update.cmd's nodejs.org/dist/latest; index.json also lists alpha builds, which are skipped)
if (-not $Version) {
    $rel = (Get-Text 'https://nodejs.org/dist/index.json' | ConvertFrom-Json) | Where-Object { $_.version -match '^v\d+\.\d+\.\d+$' } | Select-Object -First 1
    if (-not $rel) { throw "Couldn't find the latest Node.js release in https://nodejs.org/dist/index.json" }
    $Version = $rel.version
}
$ver = $Version -replace '^v'
$work = Start-Build -Name 'Node.js' -NeedGB 15
$tarball = Join-Path $work "node-v$ver.tar.xz"
Get-File "https://nodejs.org/dist/v$ver/node-v$ver.tar.xz" $tarball
Say 'Unpacking the source...'
Expand-Archive7 $tarball $work
Remove-Item -LiteralPath $tarball
$src = Join-Path $work "node-v$ver"
if (-not (Test-Path -LiteralPath (Join-Path $src 'vcbuild.bat'))) { throw "The tarball has no node-v$ver\vcbuild.bat" }

# NASM (the newest stable release from nasm.us), in the tools folder
function Use-Nasm {
    if (Get-Command nasm.exe -ErrorAction SilentlyContinue) { return }
    $dir = Get-ChildItem -LiteralPath $script:toolsDir -Directory -Filter 'nasm-*' -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $dir) {
        $base = 'https://www.nasm.us/pub/nasm/releasebuilds/'
        $nasmVer = [regex]::Matches((Get-Text $base), 'href="(\d+\.\d+(?:\.\d+)?)/"') | ForEach-Object { $_.Groups[1].Value } |
            Sort-Object { [version]$_ } | Select-Object -Last 1
        if (-not $nasmVer) { throw "Couldn't find NASM's newest release on $base" }
        Say "Getting a portable NASM ($nasmVer)..."
        $zip = Join-Path $script:toolsDir "nasm-$nasmVer-win64.zip"
        Get-File "$base$nasmVer/win64/nasm-$nasmVer-win64.zip" $zip
        [IO.Compression.ZipFile]::ExtractToDirectory($zip, $script:toolsDir); Remove-Item -LiteralPath $zip
        $dir = Get-ChildItem -LiteralPath $script:toolsDir -Directory -Filter 'nasm-*' | Select-Object -First 1
    }
    Add-ToPath $dir.FullName
}
Use-Nasm
Use-Tool python -Version '3.9'
Use-Tool rust
# (vcbuild's "package" step runs "7z"; a 7z.cmd that runs this PC's 7-Zip or the tools folder's 7za)
$bin = Join-Path $work 'bin'
New-Item -ItemType Directory -Path $bin -Force | Out-Null
[IO.File]::WriteAllText((Join-Path $bin '7z.cmd'), "@`"$(Get-SevenZip)`" %*`r`n")
Add-ToPath $bin

$env:PATH = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer;$env:PATH"
$env:MSBUILDDISABLENODEREUSE = '1'
$clang = @('Microsoft.VisualStudio.Component.VC.Tools.x86.x64', 'Microsoft.VisualStudio.Component.VC.Llvm.Clang', 'Microsoft.VisualStudio.Component.VC.Llvm.ClangToolset')
$cleanEnv = @{}; Get-ChildItem Env: | ForEach-Object { $cleanEnv[$_.Name] = $_.Value }
function Reset-Env { Get-ChildItem Env: | Where-Object { -not $cleanEnv.ContainsKey($_.Name) } | ForEach-Object { Remove-Item -LiteralPath "Env:$($_.Name)" }; foreach ($k in $cleanEnv.Keys) { Set-Item -LiteralPath "Env:$k" -Value $cleanEnv[$k] } }
function Test-VSComponent([string[]]$Components) {
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    return [bool](& $vswhere -version '[17.6,19.0)' -products * -requires $Components -property installationPath)
}

foreach ($arch in @(
        @{ Node = 'x64'; Folder = 'x64' },
        @{ Node = 'arm64'; Folder = 'ARM64'; Needs = 'Microsoft.VisualStudio.Component.VC.Tools.ARM64' })) {
    if ($arch.Needs -and -not (Test-VSComponent $arch.Needs)) { Say "Skipping $($arch.Folder): Visual Studio doesn't have $($arch.Needs)"; continue }
    Reset-Env
    # (vcbuild finds Visual Studio itself - 2026 first, then 2022 17.6 or newer - and needs its ClangCL parts; this
    # checks for them first, so a missing part is named before the build starts)
    Use-VisualStudio -Arch 'x64' -Version '[17.6,19.0)' -Components ($clang + @($arch.Needs | Where-Object { $_ })) | Out-Null
    # (vcbuild runs msbuild /m:2 with cl /MP set to NUMBER_OF_PROCESSORS: 2 keeps it to about 4 compilers at once)
    $env:NUMBER_OF_PROCESSORS = '2'
    Say "Building Node.js $ver for $($arch.Folder) (vcbuild release $($arch.Node) package)..."
    Push-Location -LiteralPath $src
    try { Invoke-Checked cmd.exe /d /c vcbuild.bat release $arch.Node package }
    finally { Pop-Location }
    $out = Join-Path $src "Release\node-v$ver-win-$($arch.Node)"
    if (-not (Test-Path -LiteralPath (Join-Path $out 'node.exe'))) { throw "vcbuild didn't make $out\node.exe" }
    Publish-Build -From $out -Arch $arch.Folder -Version $ver -Note "Source: https://nodejs.org/dist/v$ver/node-v$ver.tar.xz (vcbuild release $($arch.Node) package, ClangCL)"
    # (the next architecture starts from a clean tree)
    Push-Location -LiteralPath $src
    try { & cmd.exe /d /c vcbuild.bat clean | Out-Null } finally { Pop-Location }
}
Complete-Build
