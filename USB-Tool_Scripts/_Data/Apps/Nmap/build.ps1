param([string]$Version, [string]$WorkDir, [switch]$KeepWork, [switch]$Yes)
. "$PSScriptRoot\..\_Build-App.ps1"
trap { Stop-Build $_ }

# Builds Nmap from source (the release tarball from nmap.org/dist, github.com/nmap/nmap) into Built\x86, the way its
# Windows build does (mswin32\Build.bat and mswin32\Makefile): PCRE2 and libdnet with CMake, then MSBuild of
# mswin32\nmap.sln (Release, Win32: nmap, ncat, nping, nsock, nbase, liblua, libssh2, zlib, ...), then the files the
# Makefile's "stage-common" step puts beside nmap.exe (nmap-services, nmap-os-db and the other data files, scripts\,
# nselib\, licenses\, ncat.exe with ca-bundle.crt, nping.exe, ndiff, the OpenSSL / libssh2 / zlib DLLs).
# nmap-mswin32-aux (the Windows dependencies) as Build.bat sets it up: the Npcap SDK from npcap.com, and OpenSSL
# built from source the way nmap-mswin32-aux's OpenSSL-upgrade.txt says (the version that repository has, with its
# Configure options), with a portable Strawberry Perl and NASM.
# Differences: no Zenmap (its Windows build is a separate MSYS2 / GTK bundle), no installer (NSIS) and no Npcap
# installer - nmap.exe needs Npcap installed on the PC (the official installer offers it) for raw-packet scans;
# Visual Studio 2022 (v143) instead of 2019 (v142); the Visual C++ runtime DLLs are copied in instead of vc_redist;
# not code-signed.
# Needs: Visual Studio 2022 with C++, CMake; Strawberry Perl (portable, ~300 MB) and NASM are downloaded into the
#        tools folder when missing
# Usage: build.cmd [-Version <x.yyy>] [-KeepWork] [-WorkDir <folder>]

if (-not $Version) {
    $page = Get-Text 'https://nmap.org/download.html'
    $Version = [regex]::Matches($page, 'nmap-(\d+\.\d+)-setup\.exe') | ForEach-Object { $_.Groups[1].Value } | Sort-Object { [version]$_ } | Select-Object -Last 1
    if (-not $Version) { throw "Couldn't find the latest version on https://nmap.org/download.html" }
}
$work = Start-Build -Name 'Nmap' -NeedGB 4
$tarball = Join-Path $work "nmap-$Version.tar.bz2"
Get-File "https://nmap.org/dist/nmap-$Version.tar.bz2" $tarball
Say 'Unpacking the source...'
Expand-Archive7 $tarball $work
$src = Join-Path $work "nmap-$Version"
$mswin32 = Join-Path $src 'mswin32'
if (-not (Test-Path -LiteralPath (Join-Path $mswin32 'nmap.sln'))) { throw "The tarball has no nmap-$Version\mswin32\nmap.sln" }
if (-not (Get-Command cmake.exe -ErrorAction SilentlyContinue)) { throw 'This build needs CMake (cmake.org) on the PATH' }
# (Build.bat's NMAP_AUX_DIR: beside the source folder)
$aux = Join-Path $work 'nmap-mswin32-aux'

# the Npcap SDK (the newest on npcap.com/dist; Build.bat names 1.16)
$sdk = [regex]::Matches((Get-Text 'https://npcap.com/dist/'), 'npcap-sdk-(\d+(?:\.\d+)+)\.zip') | ForEach-Object { $_.Groups[1].Value } | Sort-Object { [version]$_ } | Select-Object -Last 1
if (-not $sdk) { $sdk = '1.16' }
$sdkZip = Join-Path $work "npcap-sdk-$sdk.zip"
Get-File "https://npcap.com/dist/npcap-sdk-$sdk.zip" $sdkZip
[IO.Compression.ZipFile]::ExtractToDirectory($sdkZip, (Join-Path $aux 'Npcap'))

# NASM and Strawberry Perl (portable) for OpenSSL, in the tools folder
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
function Use-StrawberryPerl {
    $dir = Join-Path $script:toolsDir 'strawberry-perl'
    if (-not (Test-Path -LiteralPath (Join-Path $dir 'perl\bin\perl.exe'))) {
        $rel = Get-Text 'https://api.github.com/repos/StrawberryPerl/Perl-Dist-Strawberry/releases/latest' | ConvertFrom-Json
        $asset = $rel.assets | Where-Object { $_.name -match '^strawberry-perl-[\d.]+-64bit-portable\.zip$' } | Select-Object -First 1
        if (-not $asset) { throw "Couldn't find the portable Strawberry Perl in its latest release" }
        Say "Getting a portable Strawberry Perl ($($asset.name))..."
        $zip = Join-Path $script:toolsDir $asset.name
        Get-File $asset.browser_download_url $zip
        [IO.Compression.ZipFile]::ExtractToDirectory($zip, $dir); Remove-Item -LiteralPath $zip
    }
    # (only its perl: its MinGW gcc / make stay off the PATH, so they don't get in MSVC's way)
    Add-ToPath (Join-Path $dir 'perl\bin')
}

$env:PATH = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer;$env:PATH"
$env:MSBUILDDISABLENODEREUSE = '1'
$vs = Use-VisualStudio -Arch 'x86' -Version '[17.0,18.0)' -Components 'Microsoft.VisualStudio.Component.VC.Tools.x86.x64', 'Microsoft.VisualStudio.Component.Windows11SDK.26100'

# OpenSSL: the version nmap-mswin32-aux has, built like its OpenSSL-upgrade.txt (VC-WIN32, those options, DEP / ASLR /
# SafeSEH / CFG), installed into nmap-mswin32-aux\OpenSSL
$opensslv = Get-Text 'https://svn.nmap.org/nmap-mswin32-aux/OpenSSL/include/openssl/opensslv.h'
$sslVer = [regex]::Match($opensslv, 'OPENSSL_VERSION_STR\s+"([^"]+)"').Groups[1].Value
if (-not $sslVer) { throw "Couldn't read the OpenSSL version nmap-mswin32-aux uses" }
Use-Nasm
Use-StrawberryPerl
Say "Building OpenSSL $sslVer (x86)..."
$sslTar = Join-Path $work "openssl-$sslVer.tar.gz"
Get-File "https://github.com/openssl/openssl/releases/download/openssl-$sslVer/openssl-$sslVer.tar.gz" $sslTar
Expand-Archive7 $sslTar $work
$sslSrc = Join-Path $work "openssl-$sslVer"
$sslOut = Join-Path $aux 'OpenSSL'
Push-Location -LiteralPath $sslSrc
try {
    Invoke-Checked perl Configure "--prefix=$sslOut" "--openssldir=$sslOut\ssl" no-comp enable-legacy enable-weak-ssl-ciphers enable-ssl3 enable-ssl3-method no-dso VC-WIN32
    Invoke-Checked perl -pi -e 's|$| /NXCOMPAT /DYNAMICBASE /SAFESEH /guard:cf| if /^LDFLAGS/' makefile
    Invoke-Checked perl -pi -e 's|$| /guard:cf| if /^CFLAGS/' makefile
    # (install_sw: the headers, libraries, libcrypto-3.dll / libssl-3.dll and openssl.exe, as nmap-mswin32-aux has)
    Invoke-Checked nmake /nologo -f makefile install_sw
}
finally { Pop-Location }

# PCRE2 and libdnet (Build.bat's CMake steps), then the solution
Push-Location -LiteralPath $mswin32
try {
    Say 'Configuring PCRE2 and libdnet...'
    Invoke-Checked cmake -S ..\libpcre -B build-pcre2 -G 'Visual Studio 17 2022' -A Win32
    Invoke-Checked cmake -S ..\libdnet-stripped -B build-libdnet -G 'Visual Studio 17 2022' -A Win32 "-DPacket_ROOT=$aux\Npcap"
    Say "Building Nmap $Version (nmap.sln, Release, Win32)..."
    # (the projects ask for Visual Studio 2019's v142 tools; Build.bat falls back to the newest Visual Studio)
    Invoke-Checked msbuild nmap.sln /nologo /verbosity:minimal /m:4 /p:CL_MPCount=1 /t:Build /p:Configuration=Release /p:Platform=Win32 /p:PlatformToolset=v143
}
finally { Pop-Location }

# the Makefile's stage-common / stage-nmap-main files
$out = Join-Path $work 'out'
New-Item -ItemType Directory -Path $out -Force | Out-Null
foreach ($f in 'CHANGELOG', 'LICENSE', 'nmap-mac-prefixes', 'nmap-os-db', 'nmap-protocols', 'nmap-rpc', 'nmap-service-probes', 'nmap-services', 'docs\nmap.xsl', 'nse_main.lua', 'mswin32\nmap_performance.reg', 'README-WIN32', 'docs\3rd-party-licenses.txt', 'mswin32\icon1.ico') {
    Copy-Item -LiteralPath (Join-Path $src $f) -Destination $out
}
Copy-Item -LiteralPath (Join-Path $mswin32 'Release\nmap.exe') -Destination $out
Copy-Item -Path (Join-Path $sslOut 'bin\*.dll') -Destination $out
Copy-Item -LiteralPath (Join-Path $src 'libssh2\win32\Release_dll\libssh2.dll') -Destination $out
Copy-Item -LiteralPath (Join-Path $src 'libz\contrib\vstudio\vc16\x86\ZlibDllReleaseWithoutAsm\zlibwapi.dll') -Destination $out
New-Item -ItemType Directory -Path (Join-Path $out 'scripts') -Force | Out-Null
Copy-Item -Path (Join-Path $src 'scripts\script.db'), (Join-Path $src 'scripts\*.nse') -Destination (Join-Path $out 'scripts')
Copy-Item -LiteralPath (Join-Path $src 'nselib') -Destination $out -Recurse
Copy-Item -LiteralPath (Join-Path $src 'docs\licenses') -Destination $out -Recurse
Copy-Item -LiteralPath (Join-Path $src 'ncat\Release\ncat.exe'), (Join-Path $src 'ncat\Release\ca-bundle.crt') -Destination $out
Copy-Item -LiteralPath (Join-Path $src 'nping\Release\nping.exe') -Destination $out
Copy-Item -LiteralPath (Join-Path $src 'ndiff\ndiff.py') -Destination $out
Copy-Item -LiteralPath (Join-Path $mswin32 'python-wrap.bat') -Destination (Join-Path $out 'ndiff.bat')
Copy-Item -LiteralPath (Join-Path $src 'ndiff\README') -Destination (Join-Path $out 'NDIFF_README')
# (the Visual C++ runtime the exes need, instead of the installer's vc_redist.x86.exe)
$crt = Get-ChildItem -Path (Join-Path $vs 'VC\Redist\MSVC\*\x86\Microsoft.VC14*.CRT') -Directory -ErrorAction SilentlyContinue | Sort-Object FullName | Select-Object -Last 1
if ($crt) { Copy-Item -Path (Join-Path $crt.FullName '*.dll') -Destination $out }
else { Say "(Visual Studio's x86 C++ runtime DLLs weren't found; the PC needs the Visual C++ x86 redistributable)" }
Publish-Build -From $out -Arch 'x86' -Version $Version -Note "Source: https://nmap.org/dist/nmap-$Version.tar.bz2 (MSVC v143, Win32; OpenSSL $sslVer and Npcap SDK $sdk; no Zenmap, needs Npcap installed)"
Complete-Build
