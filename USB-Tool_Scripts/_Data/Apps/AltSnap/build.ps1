param([string]$Version, [string]$WorkDir, [switch]$KeepWork, [switch]$Yes)
. "$PSScriptRoot\..\_Build-App.ps1"
trap { Stop-Build $_ }

# Builds AltSnap from source (github.com/RamonUnch/AltSnap) into Built\x86, Built\x64 and Built\ARM64, the way its
# releases are built (makerelease.bat): MinGW gcc with its Makefile (x86) and MakefileX64 (x64), and for ARM64 its
# MakefileARM64Docker without Docker, with llvm-mingw's clang. Each folder has the portable zip's files (AltSnap.exe,
# hooks.dll, AltSnap.ini, AltSnap.txt, AltSnap.xml, License.txt, sch_On/Off.bat, Lang, Themes)
# Needs: MSYS2 (MinGW gcc and make) and llvm-mingw (for ARM64); portable copies are downloaded into the tools folder
# Usage: build.cmd [-Version <x.yy>] [-KeepWork] [-WorkDir <folder>]

$repo = 'RamonUnch/AltSnap'
$tag = if ($Version) { $Version -replace '^v' } else { Get-LatestGitHubTag $repo }
$work = Start-Build -Name 'AltSnap' -NeedGB 2
$src = Join-Path $work 'src'
Get-GitSource "https://github.com/$repo.git" $tag $src

Use-Msys2 -Packages @('make', 'mingw-w64-i686-gcc', 'mingw-w64-x86_64-gcc')

# llvm-mingw (github.com/mstorsjo/llvm-mingw), a portable clang for MinGW that cross-compiles for ARM64
function Use-LlvmMingw {
    $dir = Join-Path $script:toolsDir 'llvm-mingw'
    if (-not (Test-Path -LiteralPath (Join-Path $dir 'bin\aarch64-w64-mingw32-clang.exe'))) {
        Say 'Getting a portable llvm-mingw (clang for MinGW)...'
        $release = Get-Text 'https://api.github.com/repos/mstorsjo/llvm-mingw/releases/latest' | ConvertFrom-Json
        $asset = $release.assets | Where-Object { $_.name -match '^llvm-mingw-[\d.]+-msvcrt-x86_64\.zip$' } | Select-Object -First 1
        if (-not $asset) { throw "Couldn't find llvm-mingw in its latest release" }
        $zip = Join-Path $script:toolsDir $asset.name
        Get-File $asset.browser_download_url $zip
        $tmp = Join-Path $script:toolsDir 'llvm-mingw-tmp'
        [IO.Compression.ZipFile]::ExtractToDirectory($zip, $tmp)
        if (Test-Path -LiteralPath $dir) { Remove-Item -LiteralPath $dir -Recurse -Force }
        Move-Item -LiteralPath (Get-ChildItem -LiteralPath $tmp -Directory | Select-Object -First 1).FullName -Destination $dir
        Remove-Item -LiteralPath $tmp, $zip -Recurse -Force
    }
    return (Join-Path $dir 'bin')
}
$llvmBin = Use-LlvmMingw

$files = @('AltSnap.exe', 'hooks.dll', 'AltSnap.txt', 'AltSnap.xml', 'License.txt', 'sch_On.bat', 'sch_Off.bat', 'Lang', 'Themes')
foreach ($arch in @(@{ Folder = 'x86'; Env = 'mingw32'; Make = 'make -j4 -f Makefile' }, @{ Folder = 'x64'; Env = 'mingw64'; Make = 'make -j4 -f MakefileX64' },
        @{ Folder = 'ARM64'; Env = 'mingw64'; Make = "PATH=`$(cygpath -u '$llvmBin'):`$PATH make -j4 -f MakefileARM64Docker DOCKER_RUN= CC=aarch64-w64-mingw32-clang WR=llvm-windres" })) {
    Say "Building AltSnap $tag for $($arch.Folder)..."
    $dir = Join-Path $work "build-$($arch.Folder)"
    Copy-Item -LiteralPath $src -Destination $dir -Recurse
    Invoke-Msys2 -Env $arch.Env -Command $arch.Make -Dir $dir
    # (the portable zip has the default settings, AltSnap.dni, as AltSnap.ini: it then keeps its settings there)
    Copy-Item -LiteralPath (Join-Path $dir 'AltSnap.dni') -Destination (Join-Path $dir 'AltSnap.ini')
    Publish-Build -From $dir -Arch $arch.Folder -Version $tag -Files ($files + 'AltSnap.ini') -Note "Source: https://github.com/$repo, tag $tag"
}
Complete-Build
