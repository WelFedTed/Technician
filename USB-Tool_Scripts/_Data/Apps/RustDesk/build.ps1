param([string]$Version, [string]$WorkDir, [switch]$KeepWork, [switch]$Yes)
. "$PSScriptRoot\..\_Build-App.ps1"
trap { Stop-Build $_ }

# Builds RustDesk from source (github.com/rustdesk/rustdesk) into Built\x64, the way its flutter-build.yml workflow
# builds the Windows x64 release: the Flutter bridge (bridge.yml: flutter_rust_bridge_codegen), the vcpkg libraries
# (x64-windows-static, at the workflow's vcpkg commit), "python build.py --portable --flutter --skip-portable-pack
# --hwcodec --vram" with Rust 1.75, LLVM 15 and Flutter 3.24.5 with RustDesk's own Flutter engine and patch, then the
# extras the workflow adds (usbmmidd_v2, the printer driver, RustDeskTempTopMostWindow's WindowInjection.dll) and
# libs\portable's packer, which makes the single rustdesk-<version>-x86_64.exe update.cmd downloads.
# Not built: the MSI, the 32-bit Sciter exe, ARM64; not code-signed. A very large build (hours, ~40 GB).
# Needs: Visual Studio 2022 with the C++ tools, Rust (rustup; it adds the 1.75 toolchain), Python, Git; LLVM 15,
# Flutter 3.24.5, vcpkg and the bridge generator are downloaded into the tools folder
# Usage: build.cmd [-Version <x.y.z>] [-KeepWork] [-WorkDir <folder>]

$repo = 'rustdesk/rustdesk'
$tag = if ($Version) { $Version -replace '^v' } else { Get-LatestGitHubTag $repo }
$work = Start-Build -Name 'RustDesk' -NeedGB 40
$src = Join-Path $work 'src'
$env:GIT_CONFIG_COUNT = '1'; $env:GIT_CONFIG_KEY_0 = 'core.longpaths'; $env:GIT_CONFIG_VALUE_0 = 'true'
Get-GitSource "https://github.com/$repo.git" $tag $src -Submodules
$git = Get-Git
Add-ToPath (Split-Path -Parent $git)

# the versions the workflows pin
$wf = [IO.File]::ReadAllText((Join-Path $src '.github\workflows\flutter-build.yml'))
$bridgeWf = [IO.File]::ReadAllText((Join-Path $src '.github\workflows\bridge.yml'))
$pin = { param($text, $name) $m = [regex]::Match($text, "(?m)^\s*$name\s*:\s*`"([^`"]+)`""); if (-not $m.Success) { throw "Couldn't find $name in the workflow" }; $m.Groups[1].Value }
$rustVersion = & $pin $wf 'RUST_VERSION'
$llvmVersion = & $pin $wf 'LLVM_VERSION'
$flutterVersion = & $pin $wf 'FLUTTER_VERSION'
$vcpkgCommit = & $pin $wf 'VCPKG_COMMIT_ID'
$frbVersion = & $pin $bridgeWf 'FLUTTER_RUST_BRIDGE_VERSION'
$expandVersion = & $pin $bridgeWf 'CARGO_EXPAND_VERSION'
Say "Rust $rustVersion, LLVM $llvmVersion, Flutter $flutterVersion, vcpkg $vcpkgCommit, flutter_rust_bridge $frbVersion"

Use-VisualStudio -Arch x64 -Version '[17.0,18.0)' | Out-Null
Use-Tool python -Version '3.10'
Use-Tool rust
Invoke-Checked rustup toolchain install $rustVersion --profile minimal --component rustfmt --target x86_64-pc-windows-msvc
$env:RUSTUP_TOOLCHAIN = $rustVersion
$env:CARGO_BUILD_JOBS = '4'

# LLVM (libclang for bindgen and the bridge generator): unpacked from its NSIS installer with 7-Zip, not installed
$llvmDir = Join-Path $script:toolsDir "llvm-$llvmVersion"
if (-not (Test-Path -LiteralPath (Join-Path $llvmDir 'bin\libclang.dll'))) {
    Say "Getting LLVM $llvmVersion (unpacked, not installed)..."
    $exe = Join-Path $work "LLVM-$llvmVersion-win64.exe"
    Get-File "https://github.com/llvm/llvm-project/releases/download/llvmorg-$llvmVersion/LLVM-$llvmVersion-win64.exe" $exe
    Invoke-Checked (Get-SevenZip) x $exe "-o$llvmDir" -y | Out-Null
    Remove-Item -LiteralPath (Join-Path $llvmDir '$PLUGINSDIR') -Recurse -Force -ErrorAction SilentlyContinue
}
$env:LIBCLANG_PATH = Join-Path $llvmDir 'bin'
Add-ToPath (Join-Path $llvmDir 'bin')

# Flutter, with RustDesk's engine and its dropdown patch (as the workflow does), in the tools folder
$flutterDir = Join-Path $script:toolsDir "flutter-$flutterVersion"
$env:PUB_CACHE = Join-Path $script:toolsDir 'pub-cache'
$env:FLUTTER_SUPPRESS_ANALYTICS = 'true'; $env:DART_SUPPRESS_ANALYTICS = 'true'
if (-not (Test-Path -LiteralPath (Join-Path $flutterDir 'rustdesk-ready.txt'))) {
    if (Test-Path -LiteralPath $flutterDir) { Remove-Item -LiteralPath $flutterDir -Recurse -Force }
    # (a clone of its release tag, Flutter's own way to install it: the release zip has paths too long to unpack
    # with Windows PowerShell; core.longpaths is set above)
    Get-GitSource 'https://github.com/flutter/flutter.git' $flutterVersion $flutterDir
    Add-ToPath (Join-Path $flutterDir 'bin')
    Invoke-Checked flutter.bat config --no-analytics
    Invoke-Checked flutter.bat precache --windows
    Say "Putting in RustDesk's Flutter engine..."
    $eng = Join-Path $work 'windows-x64-release.zip'
    Get-File 'https://github.com/rustdesk/engine/releases/download/main/windows-x64-release.zip' $eng
    Expand-Archive7 $eng (Join-Path $work 'engine')
    Copy-Item -Path (Join-Path $work 'engine\*') -Destination (Join-Path $flutterDir 'bin\cache\artifacts\engine\windows-x64-release') -Recurse -Force
    $patch = Join-Path $src '.github\patches\flutter_3.24.4_dropdown_menu_enableFilter.diff'
    if ($flutterVersion -eq '3.24.5' -and (Test-Path -LiteralPath $patch)) { Invoke-Checked $git -C $flutterDir apply $patch }
    [IO.File]::WriteAllText((Join-Path $flutterDir 'rustdesk-ready.txt'), "Flutter $flutterVersion with RustDesk's engine and patch`r`n")
}
Add-ToPath (Join-Path $flutterDir 'bin')

# vcpkg at the workflow's commit, with its binary cache in the tools folder
# (a short folder name: vcpkg's builds go deep, and Windows paths stop at 260 characters)
$vcpkg = Join-Path $script:toolsDir "vcpkg-$($vcpkgCommit.Substring(0, 8))"
if (-not (Test-Path -LiteralPath (Join-Path $vcpkg 'vcpkg.exe'))) {
    Say 'Getting vcpkg...'
    if (Test-Path -LiteralPath $vcpkg) { Remove-Item -LiteralPath $vcpkg -Recurse -Force }
    # (a full clone: RustDesk's vcpkg.json pins versions, which vcpkg reads from its git history)
    Invoke-Checked $git clone -q https://github.com/microsoft/vcpkg.git $vcpkg
    Invoke-Checked $git -C $vcpkg -c advice.detachedHead=false checkout -q $vcpkgCommit
    # (vcpkg runs git itself to read the pinned port versions; long paths on for that repository)
    Invoke-Checked $git -C $vcpkg config core.longpaths true
    Invoke-Checked cmd.exe /d /c "`"$(Join-Path $vcpkg 'bootstrap-vcpkg.bat')`" -disableMetrics"
}
$env:VCPKG_ROOT = $vcpkg
$env:VCPKG_DEFAULT_HOST_TRIPLET = 'x64-windows-static'
$env:VCPKG_DEFAULT_BINARY_CACHE = Join-Path $script:toolsDir 'vcpkg-cache'
$env:VCPKG_MAX_CONCURRENCY = '4'
New-Item -ItemType Directory -Path $env:VCPKG_DEFAULT_BINARY_CACHE -Force | Out-Null

Push-Location -LiteralPath $src
try {
    Say 'Building the vcpkg libraries (x64-windows-static; ffmpeg, libvpx, opus... this takes a while)...'
    Invoke-Checked (Join-Path $vcpkg 'vcpkg.exe') install --triplet x64-windows-static "--x-install-root=$vcpkg\installed" --disable-metrics

    # the Flutter <-> Rust bridge (bridge.yml)
    $frbRoot = Join-Path $script:toolsDir "frb-$frbVersion"
    if (-not (Test-Path -LiteralPath (Join-Path $frbRoot 'bin\flutter_rust_bridge_codegen.exe'))) {
        Say 'Getting the bridge generator (cargo install)...'
        Invoke-Checked cargo install cargo-expand --version $expandVersion --locked --root $frbRoot
        Invoke-Checked cargo install flutter_rust_bridge_codegen --version $frbVersion --features uuid --locked --root $frbRoot
    }
    Add-ToPath (Join-Path $frbRoot 'bin')
    Say 'Generating the bridge...'
    Push-Location -LiteralPath (Join-Path $src 'flutter'); try { Invoke-Checked flutter.bat pub get } finally { Pop-Location }
    Invoke-Checked flutter_rust_bridge_codegen.exe --rust-input ./src/flutter_ffi.rs --dart-output ./flutter/lib/generated_bridge.dart --c-output ./flutter/macos/Runner/bridge_generated.h --llvm-path $llvmDir

    Say 'Building RustDesk (build.py --portable --flutter --hwcodec --vram)...'
    Invoke-Checked python.exe .\build.py --portable --flutter --skip-portable-pack --hwcodec --vram
}
finally { Pop-Location }

$rd = Join-Path $work 'rustdesk'
Move-Item -LiteralPath (Join-Path $src 'flutter\build\windows\x64\runner\Release') -Destination $rd

# the extras the workflow adds to the folder
Say 'Adding usbmmidd_v2, the printer driver and RustDeskTempTopMostWindow...'
Get-File 'https://github.com/rustdesk-org/rdev/releases/download/usbmmidd_v2/usbmmidd_v2.zip' (Join-Path $work 'usbmmidd_v2.zip')
Expand-Archive7 (Join-Path $work 'usbmmidd_v2.zip') $work
Remove-Item -LiteralPath (Join-Path $work 'usbmmidd_v2\Win32') -Recurse -Force -ErrorAction SilentlyContinue
foreach ($f in 'deviceinstaller64.exe', 'deviceinstaller.exe', 'usbmmidd.bat') { Remove-Item -LiteralPath (Join-Path $work "usbmmidd_v2\$f") -Force -ErrorAction SilentlyContinue }
Move-Item -LiteralPath (Join-Path $work 'usbmmidd_v2') -Destination $rd
try {
    $base = 'https://github.com/rustdesk/hbb_common/releases/download/driver'
    Get-File "$base/rustdesk_printer_driver_v4-1.4.zip" (Join-Path $work 'printer_driver.zip')
    Get-File "$base/printer_driver_adapter.zip" (Join-Path $work 'printer_adapter.zip')
    $sums = Get-Text "$base/sha256sums"
    $want1 = [regex]::Match($sums, '(?m)^([a-fA-F0-9]{64}) \*rustdesk_printer_driver_v4-1\.4\.zip').Groups[1].Value
    $want2 = [regex]::Match($sums, '(?m)^([a-fA-F0-9]{64}) \*printer_driver_adapter\.zip').Groups[1].Value
    if ($want1 -eq (Get-FileHash (Join-Path $work 'printer_driver.zip')).Hash -and $want2 -eq (Get-FileHash (Join-Path $work 'printer_adapter.zip')).Hash) {
        Expand-Archive7 (Join-Path $work 'printer_driver.zip') (Join-Path $work 'printer')
        New-Item -ItemType Directory -Path (Join-Path $rd 'drivers') -Force | Out-Null
        Move-Item -LiteralPath (Join-Path $work 'printer\rustdesk_printer_driver_v4-1.4') -Destination (Join-Path $rd 'drivers\RustDeskPrinterDriver')
        Expand-Archive7 (Join-Path $work 'printer_adapter.zip') (Join-Path $work 'printer')
        Copy-Item -LiteralPath (Join-Path $work 'printer\printer_driver_adapter.dll') -Destination $rd
    }
    else { Say 'The printer driver files'' checksums don''t match, so they''re left out (as the workflow does)' }
}
catch { Say "Left out the printer driver ($($_.Exception.Message))" }
$tw = Join-Path $work 'RustDeskTempTopMostWindow'
$twYml = [IO.File]::ReadAllText((Join-Path $src '.github\workflows\third-party-RustDeskTempTopMostWindow.yml'))
$twCommit = [regex]::Match($twYml, 'git checkout ([0-9a-f]{40})').Groups[1].Value
Invoke-Checked $git clone -q https://github.com/rustdesk-org/RustDeskTempTopMostWindow $tw
if ($twCommit) { Invoke-Checked $git -C $tw -c advice.detachedHead=false checkout -q $twCommit }
Invoke-Checked msbuild.exe (Join-Path $tw 'WindowInjection\WindowInjection.vcxproj') /nologo /m:4 -p:Configuration=Release -p:Platform=x64 /p:TargetVersion=Windows10
$dll = Get-ChildItem -LiteralPath $tw -Recurse -Filter 'WindowInjection.dll' | Where-Object { $_.FullName -match '\\Release\\' } | Select-Object -First 1
if ($dll) { Copy-Item -LiteralPath $dll.FullName -Destination $rd } else { throw "RustDeskTempTopMostWindow didn't make WindowInjection.dll" }

# the single portable exe (libs\portable's packer), with the version resource from Runner.res
$res = Get-ChildItem -LiteralPath (Join-Path $src 'flutter\build') -Recurse -Filter 'Runner.res' -ErrorAction SilentlyContinue | Select-Object -First 1
if ($res) { Copy-Item -LiteralPath $res.FullName -Destination (Join-Path $src 'libs\portable\Runner.res') }
Push-Location -LiteralPath (Join-Path $src 'libs\portable')
try { Invoke-Checked python.exe .\generate.py -f ../../../rustdesk/ -o . -e ../../../rustdesk/rustdesk.exe }
finally { Pop-Location }
$packer = Join-Path $src 'libs\portable\target\release\rustdesk-portable-packer.exe'
if (-not (Test-Path -LiteralPath $packer)) { throw "The packer wasn't built" }
$out = Join-Path $work 'out'
New-Item -ItemType Directory -Path $out -Force | Out-Null
Copy-Item -LiteralPath $packer -Destination (Join-Path $out "rustdesk-$tag-x86_64.exe")
Publish-Build -From $out -Arch 'x64' -Version $tag -Note "Source: https://github.com/$repo, tag $tag (Rust $rustVersion, Flutter $flutterVersion; not signed)"
Complete-Build
