param([string]$Version, [string]$WorkDir, [switch]$KeepWork, [switch]$Yes)
. "$PSScriptRoot\..\_Build-App.ps1"
trap { Stop-Build $_ }

# Builds LocalSend from source (github.com/localsend/localsend) into Built\x64, the way its release workflows
# build the portable zip (build_zip_test.yml: flutter build windows, plus settings.json and the MSVC runtime DLLs
# from the repo) and the command line exe (build_cli_exe_test.yml: cargo build --package localsend-cli, saved
# beside the app as localsend.exe, the name update.cmd gives it in CLI\x64)
# Needs: Visual Studio 2022 with the C++ tools; Flutter (the version the project pins in .fvmrc: a git clone of it
# is kept in the tools folder); Rust (the version rust-toolchain.toml pins, with a portable rustup in the tools
# folder); CMake (this PC's, or a portable copy). ARM64 isn't built: Flutter only builds Windows ARM64 apps on an
# ARM64 PC (and with a beta Flutter, as the project's own ARM64 workflow says).
# Usage: build.cmd [-Version <x.y.z>] [-KeepWork] [-WorkDir <folder>]

# ---------------------------------------------------------------------------------------------
# Flutter, Rust and CMake helpers (the same in Plezy's build.ps1)
# ---------------------------------------------------------------------------------------------

# a Flutter SDK of this version (a shallow git clone of its tag) in the tools folder; returns flutter.bat
# -Folder: another folder name, for an SDK the build changes (eg. Plezy's patched engine)
function Use-Flutter([string]$FlutterVersion, [string]$Folder) {
    $dir = Join-Path $script:toolsDir $(if ($Folder) { $Folder } else { "flutter-$FlutterVersion" })
    $flutter = Join-Path $dir 'bin\flutter.bat'
    if (-not (Test-Path -LiteralPath $flutter)) {
        Say "Getting Flutter $FlutterVersion..."
        if (Test-Path -LiteralPath $dir) { Remove-Item -LiteralPath $dir -Recurse -Force }
        Invoke-Checked (Get-Git) -c core.longpaths=true -c advice.detachedHead=false clone --depth 1 --branch $FlutterVersion https://github.com/flutter/flutter.git $dir | Out-Host
    }
    # Flutter links each plugin's source into the project with a symbolic link, which Windows only allows with
    # Developer Mode on (or as admin). So when that's refused, the flutter tool here makes a directory junction
    # instead (which any user can), rather than stopping with "Building with plugins requires symlink support".
    $plugins = Join-Path $dir 'packages\flutter_tools\lib\src\flutter_plugins.dart'
    $code = [IO.File]::ReadAllText($plugins)
    if ($code -notmatch 'USB-Tool build') {
        $m = [regex]::Match($code, '      link\.createSync\(path\);(\r?\n)    \} on FileSystemException catch \(e\) \{\r?\n')
        if (-not $m.Success) { throw "Couldn't find where Flutter $FlutterVersion makes its plugin symlinks (in $plugins)" }
        $nl = $m.Groups[1].Value
        $add = @(
            "      // (USB-Tool build.ps1: without Developer Mode, a directory junction instead of a symlink)"
            "      if (globals.platform.isWindows && e.osError?.errorCode == 1314 &&"
            "          globals.processManager.runSync(<String>['cmd', '/c', 'mklink', '/J', link.path, path]).exitCode == 0) {"
            "        continue;"
            "      }"
        ) -join $nl
        [IO.File]::WriteAllText($plugins, $code.Insert($m.Index + $m.Length, $add + $nl))
        # (the flutter tool is rebuilt from its source on its next start)
        Remove-Item -LiteralPath (Join-Path $dir 'bin\cache\flutter_tools.snapshot'), (Join-Path $dir 'bin\cache\flutter_tools.stamp') -Force -ErrorAction SilentlyContinue
    }
    # (the pub package cache goes in the tools folder too, not in the PC's user profile)
    $env:PUB_CACHE = Join-Path $script:toolsDir 'pub-cache'
    $env:FLUTTER_SUPPRESS_ANALYTICS = 'true'
    # (as flutter.bat sets for what it runs: eg. cargokit's build scripts find Dart with it)
    $env:FLUTTER_ROOT = $dir
    # (long paths for the git that pub runs for git dependencies, whose clones are deep in the pub cache)
    if (-not $env:GIT_CONFIG_COUNT) { $env:GIT_CONFIG_COUNT = '1'; $env:GIT_CONFIG_KEY_0 = 'core.longpaths'; $env:GIT_CONFIG_VALUE_0 = 'true' }
    Add-ToPath (Join-Path $dir 'bin')
    # (its first start gets the Dart SDK and builds the flutter tool; run in the work folder, where it would
    # write a crash log)
    Push-Location -LiteralPath $script:Work
    try { Invoke-Checked $flutter --version --suppress-analytics | Out-Host }
    finally { Pop-Location }
    return $flutter
}

# CMake: this PC's, or a portable copy in the tools folder
function Use-CMake {
    $c = Get-Command cmake.exe -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($c) { return $c.Source }
    $dir = Get-ChildItem -LiteralPath $script:toolsDir -Directory -Filter 'cmake-*-windows-x86_64' -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $dir) {
        $release = Get-Text 'https://api.github.com/repos/Kitware/CMake/releases/latest' | ConvertFrom-Json
        $asset = $release.assets | Where-Object { $_.name -match '^cmake-[\d.]+-windows-x86_64\.zip$' } | Select-Object -First 1
        if (-not $asset) { throw "Couldn't find CMake's Windows zip in its latest release" }
        Say "Getting a portable CMake ($($release.tag_name))..."
        $zip = Join-Path $script:toolsDir $asset.name; Get-File $asset.browser_download_url $zip
        [IO.Compression.ZipFile]::ExtractToDirectory($zip, $script:toolsDir); Remove-Item -LiteralPath $zip
        $dir = Get-ChildItem -LiteralPath $script:toolsDir -Directory -Filter 'cmake-*-windows-x86_64' | Select-Object -First 1
    }
    return (Join-Path $dir.FullName 'bin\cmake.exe')
}

# flutter build windows --release in this project folder. Flutter only accepts a Visual Studio with its C++
# workload and "C++ CMake tools for Windows"; without those (but with the C++ tools, which Use-VisualStudio has
# checked) flutter build windows still writes the project's generated files and then stops, and its two CMake
# steps are run here instead, the same way (configure for the Visual Studio generator, then build the INSTALL
# target, which runs flutter assemble for the Dart code).
function Invoke-FlutterBuildWindows([string]$Flutter, [string]$ProjectDir, [string]$Arch = 'x64', [string[]]$BuildArgs) {
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    $flutterLikesVS = $false
    foreach ($workload in 'Microsoft.VisualStudio.Workload.NativeDesktop', 'Microsoft.VisualStudio.Workload.VCTools') {
        if (& $vswhere -version 16 -products * -requires $workload Microsoft.VisualStudio.Component.VC.Tools.x86.x64 Microsoft.VisualStudio.Component.VC.CMake.Project -property installationPath) { $flutterLikesVS = $true }
    }
    Push-Location -LiteralPath $ProjectDir
    try {
        if ($flutterLikesVS) {
            Invoke-Checked $Flutter build windows --release --suppress-analytics @BuildArgs
            return
        }
        Say "(Visual Studio has no C++ CMake tools, which flutter build windows looks for, so its CMake steps are run here)"
        $ErrorActionPreference = 'Continue'
        $output = & $Flutter build windows --release --suppress-analytics @BuildArgs 2>&1 | ForEach-Object { $line = "$_"; Write-Host $line; $line }
        $code = $LASTEXITCODE
        $ErrorActionPreference = 'Stop'
        if ($code -eq 0) { return }
        if (-not ($output -match 'Unable to find suitable Visual Studio toolchain')) { throw "flutter build windows failed (exit code $code)" }
        $cmake = Use-CMake
        $buildDir = Join-Path $ProjectDir "build\windows\$($Arch.ToLower())"
        $configure = @('-S', (Join-Path $ProjectDir 'windows'), '-B', $buildDir, '-G', 'Visual Studio 17 2022', '-A', $(if ($Arch -eq 'arm64') { 'ARM64' } else { 'x64' }),
            "-DFLUTTER_TARGET_PLATFORM=windows-$($Arch.ToLower())", '-DCMAKE_POLICY_VERSION_MINIMUM=3.5')
        if ($script:vsPath) { $configure += "-DCMAKE_GENERATOR_INSTANCE=$($script:vsPath)" }
        Say ''
        Say "Building with $cmake..."
        Invoke-Checked $cmake @configure
        Invoke-Checked $cmake --build $buildDir --config Release --target INSTALL --parallel 4
    }
    finally { Pop-Location }
}

# a portable rustup in the tools folder (so the toolchain a project pins is downloaded there, not into the PC's
# own rustup); the project's rust-toolchain.toml then picks the toolchain
function Use-PortableRust {
    $env:RUSTUP_HOME = Join-Path $script:toolsDir 'rustup'; $env:CARGO_HOME = Join-Path $script:toolsDir 'cargo'
    if (-not (Test-Path -LiteralPath "$env:CARGO_HOME\bin\rustup.exe")) {
        Say 'Getting a portable Rust (rustup)...'
        $init = Join-Path $script:toolsDir 'rustup-init.exe'; Get-File 'https://static.rust-lang.org/rustup/dist/x86_64-pc-windows-msvc/rustup-init.exe' $init
        Invoke-Checked $init -y --no-modify-path --profile minimal --default-toolchain none
    }
    Add-ToPath "$env:CARGO_HOME\bin"
}

# ---------------------------------------------------------------------------------------------
# LocalSend
# ---------------------------------------------------------------------------------------------

$repo = 'localsend/localsend'
$tag = if ($Version) { 'v' + ($Version -replace '^v') } else { Get-LatestGitHubTag $repo }
$work = Start-Build -Name 'LocalSend' -NeedGB 10
$src = Join-Path $work 'src'
Get-GitSource "https://github.com/$repo.git" $tag $src
$app = Join-Path $src 'app'

Use-VisualStudio -Arch x64 -Version '[17.0,18.0)' -Components 'Microsoft.VisualStudio.Component.VC.Tools.x86.x64' | Out-Null

# Rust (the Flutter app's network code is a Rust library, built by cargokit during the Flutter build; and the CLI)
Use-PortableRust
Push-Location -LiteralPath $src
try { Invoke-Checked rustup toolchain install }
finally { Pop-Location }

# Flutter (the version in .fvmrc, as the workflows' FLUTTER_VERSION)
$flutterVersion = (Get-Content -LiteralPath (Join-Path $src '.fvmrc') -Raw | ConvertFrom-Json).flutter
if (-not $flutterVersion) { throw "Couldn't read the Flutter version from .fvmrc" }
$flutter = Use-Flutter $flutterVersion

# the MSIX helper, which app\windows\CMakeLists.txt installs (and which the portable build then removes): built with
# the Windows SDK's makepri / makeappx, as the workflow does, or an empty stand-in when this PC doesn't have them
$msix = Join-Path $app 'windows\localsend_msix_helper.msix'
$makepri = Get-ChildItem "${env:ProgramFiles(x86)}\Windows Kits\10\bin\10.*\x64\makepri.exe" -ErrorAction SilentlyContinue | Select-Object -Last 1
$makeappx = "${env:ProgramFiles(x86)}\Windows Kits\10\App Certification Kit\makeappx.exe"
if ($makepri -and (Test-Path -LiteralPath $makeappx) -and (Test-Path -LiteralPath (Join-Path $src 'support\build\msix'))) {
    Push-Location -LiteralPath $src
    try {
        Invoke-Checked $makepri.FullName new /pr support\build\msix\content /cf support\build\msix\priconfig.xml /mn support\build\msix\content\AppxManifest.xml /of support\build\msix\content\resources.pri /o | Out-Null
        Invoke-Checked $makeappx pack /o /d support\build\msix\content /nv /p $msix | Out-Null
    }
    finally { Pop-Location }
}
elseif (-not (Test-Path -LiteralPath $msix)) { [IO.File]::WriteAllBytes($msix, [byte[]]@()) }

Say ''
Say 'Building LocalSend...'
Push-Location -LiteralPath $app
try { Invoke-Checked $flutter pub get --suppress-analytics }
finally { Pop-Location }
Invoke-FlutterBuildWindows -Flutter $flutter -ProjectDir $app -Arch x64

# the portable zip's extras: an empty settings.json (which makes it keep its settings beside the exe), and the
# MSVC runtime DLLs from the repo; without the MSIX helper and the exe manifest that only the installer uses
$out = Join-Path $app 'build\windows\x64\runner\Release'
[IO.File]::WriteAllText((Join-Path $out 'settings.json'), "{}`r`n")
foreach ($dll in 'msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll') { Copy-Item -LiteralPath (Join-Path $src "support\build\windows\x64\$dll") -Destination $out }
foreach ($extra in 'localsend_msix_helper.msix', 'install_msix_helper.ps1', 'localsend_app.exe.manifest') { Remove-Item -LiteralPath (Join-Path $out $extra) -Force -ErrorAction SilentlyContinue }

Say ''
Say 'Building the LocalSend command line (localsend.exe)...'
Push-Location -LiteralPath $src
try { Invoke-Checked cargo build --release --package localsend-cli -j 4 }
finally { Pop-Location }
Copy-Item -LiteralPath (Join-Path $src 'target\release\localsend-cli.exe') -Destination (Join-Path $out 'localsend.exe')

Publish-Build -From $out -Arch x64 -Version ($tag -replace '^v') -Note "Source: https://github.com/$repo, tag $tag (Flutter $flutterVersion). localsend.exe is the command line version (LocalSend-CLI)."
Complete-Build
