param([string]$Version, [string]$WorkDir, [switch]$KeepWork, [switch]$Yes)
. "$PSScriptRoot\..\_Build-App.ps1"
trap { Stop-Build $_ }

# Builds ODIN (Open Disk Imager in a Nutshell) from source (ODIN-<version>-src.zip from sourceforge.net/projects/odin-win)
# into Built\x64 and Built\x86, like the ODIN-<version>-64Bit / -32Bit zips update.cmd downloads: ODIN.exe (the GUI,
# which asks for admin) and ODINC.exe (the command line version).
# The source's own build (doc\HowToBuild.txt) is Visual C++ 2008 with ODIN.sln's .vcproj projects, ATL 3.0 and WTL 8.0;
# today's Visual Studio can't open .vcproj files any more, so this makes a CMake project with the same sources,
# settings and libraries as those .vcproj files (zlib, libbz2, ODIN, ODINC: Unicode, static C runtime, version.lib and
# shlwapi.lib), built with Visual Studio 2022's ATL and WTL 10 (the "wtl" NuGet package, WTL's own release).
# Differences: zlib without its 2008-era assembly files (the plain C code, same results); the Windows version macros
# in stdafx.h are raised to Windows 7 (today's ATL / WTL refuse the old Windows 2000 values); no ODIN.chm help file
# (it needs the HTML Help Workshop, which only comes as an installer).
# Needs: Visual Studio 2022 with C++ and ATL (Microsoft.VisualStudio.Component.VC.ATL), CMake
# Usage: build.cmd [-Version <x.yy>] [-KeepWork] [-WorkDir <folder>]

$files = 'https://sourceforge.net/projects/odin-win/files/ODIN/'
if (-not $Version) {
    # (the newest version folder on the files page update.cmd reads)
    $page = Get-Text $files
    $Version = [regex]::Matches($page, '/projects/odin-win/files/ODIN/(\d+(?:\.\d+)+)/') | ForEach-Object { $_.Groups[1].Value } |
        Sort-Object { [version]$_ } | Select-Object -Last 1
    if (-not $Version) { throw "Couldn't find the latest version on $files" }
}
$work = Start-Build -Name 'ODIN' -NeedGB 1
$src = Join-Path $work 'src'
$zip = Join-Path $work "ODIN-$Version-src.zip"
Get-File "$files$Version/ODIN-$Version-src.zip/download" $zip
[IO.Compression.ZipFile]::ExtractToDirectory($zip, $src)
if (-not (Test-Path -LiteralPath (Join-Path $src 'ODIN.vcproj'))) { throw "ODIN-$Version-src.zip has no ODIN.vcproj" }
if (-not (Get-Command cmake.exe -ErrorAction SilentlyContinue)) { throw 'This build needs CMake (cmake.org) on the PATH' }

# WTL (headers only) from its NuGet package
$wtlPkg = Join-Path $work 'wtl.nupkg'
Get-File 'https://www.nuget.org/api/v2/package/wtl' $wtlPkg
[IO.Compression.ZipFile]::ExtractToDirectory($wtlPkg, (Join-Path $work 'wtl'))
$wtlInclude = (Join-Path $work 'wtl\lib\native\include') -replace '\\', '/'

# (today's ATL and WTL need at least Windows XP's version macros; Windows 7's are used)
$stdafx = Join-Path $src 'src\ODIN\stdafx.h'
$text = [IO.File]::ReadAllText($stdafx)
$text = $text -replace '#define WINVER\s+0x0500', '#define WINVER 0x0601' -replace '#define _WIN32_WINNT\s+0x0502', '#define _WIN32_WINNT 0x0601' -replace '#define _WIN32_IE\s+0x0502', '#define _WIN32_IE 0x0800'
[IO.File]::WriteAllText($stdafx, $text)

# the CMake project, from the .vcproj files' sources and Release settings (the source list is read from each .vcproj)
function Get-VcprojSources([string]$vcproj, [string]$pattern) {
    ([xml](Get-Content -LiteralPath (Join-Path $src $vcproj) -Raw)).SelectNodes('//File') | ForEach-Object { $_.RelativePath } |
        Where-Object { $_ -match $pattern } | ForEach-Object { ($_ -replace '^\.\\', '') -replace '\\', '/' }
}
$zlibSources = Get-VcprojSources 'zlib.vcproj' '\.c$' | Where-Object { $_ -notmatch '(gvmat32c|inffas8664|inffas86)\.c$' }
$bz2Sources = Get-VcprojSources 'libz2.vcproj' '\.c$'
$odinSources = @(Get-VcprojSources 'ODIN.vcproj' '\.(cpp|rc)$')
$odincSources = Get-VcprojSources 'ODINC.vcproj' '\.cpp$'
$cmake = @"
cmake_minimum_required(VERSION 3.16)
project(ODIN C CXX RC)
set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded")
add_compile_definitions(UNICODE _UNICODE NDEBUG _CRT_SECURE_NO_WARNINGS _CRT_NON_CONFORMING_SWPRINTFS)
add_library(zlib STATIC $($zlibSources -join ' '))
target_compile_definitions(zlib PRIVATE WINDOWS)
add_library(libz2 STATIC $($bz2Sources -join ' '))
add_executable(ODIN WIN32 $($odinSources -join ' ') ODIN.exe.manifest)
target_compile_definitions(ODIN PRIVATE STRICT `$<`$<EQUAL:`${CMAKE_SIZEOF_VOID_P},8>:WIN64>)
target_include_directories(ODIN PRIVATE src/ODIN src/zlib.1.2.3 src/bzip2-1.0.5 "$wtlInclude")
target_compile_options(ODIN PRIVATE /EHsc /permissive /Zc:wchar_t)
target_link_libraries(ODIN PRIVATE zlib libz2 version shlwapi)
target_link_options(ODIN PRIVATE /MANIFESTUAC:NO)
add_executable(ODINC $($odincSources -join ' '))
target_link_libraries(ODINC PRIVATE version shlwapi)
"@
[IO.File]::WriteAllText((Join-Path $src 'CMakeLists.txt'), $cmake)

$env:PATH = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer;$env:PATH"
$env:MSBUILDDISABLENODEREUSE = '1'
foreach ($arch in @(@{ CMake = 'x64'; Folder = 'x64'; Bits = '64' }, @{ CMake = 'Win32'; Folder = 'x86'; Bits = '32' })) {
    Use-VisualStudio -Arch 'x64' -Version '[17.0,18.0)' -Components 'Microsoft.VisualStudio.Component.VC.Tools.x86.x64', 'Microsoft.VisualStudio.Component.VC.ATL' | Out-Null
    Say "Building ODIN $Version for $($arch.Folder)..."
    $build = Join-Path $work "build-$($arch.Folder)"
    Invoke-Checked cmake -S $src -B $build -G 'Visual Studio 17 2022' -A $arch.CMake
    Invoke-Checked cmake --build $build --config Release --parallel 4
    $out = Join-Path $work "out\$($arch.Folder)"
    New-Item -ItemType Directory -Path $out -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $build 'Release\ODIN.exe'), (Join-Path $build 'Release\ODINC.exe') -Destination $out
    foreach ($doc in 'doc\license.html', 'doc\readme.txt', 'doc\changelist.txt') { if (Test-Path -LiteralPath (Join-Path $src $doc)) { Copy-Item -LiteralPath (Join-Path $src $doc) -Destination $out } }
    Publish-Build -From $out -Arch $arch.Folder -Version $Version -Note "Source: $files$Version/ODIN-$Version-src.zip (CMake project made from the .vcproj files; MSVC v143, ATL, WTL 10)"
}
Complete-Build
