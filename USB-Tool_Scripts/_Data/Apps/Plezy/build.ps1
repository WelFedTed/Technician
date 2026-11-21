param([string]$Version, [string]$WorkDir, [switch]$KeepWork, [switch]$Yes)
. "$PSScriptRoot\..\_Build-App.ps1"
trap { Stop-Build $_ }

# Builds Plezy from source (github.com/edde746/plezy) into Built\x64, the way its release workflow
# (.github/workflows/build.yml, build-windows) builds the Windows app: Flutter with the project's patched Flutter
# engine (windows\tool\install-patched-engine.ps1, which the app needs for its video window), then
# flutter build windows --release; the portable 7z is that build's Release folder as it is (with libmpv-2.dll,
# vulkan-1.dll and the MSVC runtime, which the project's CMake build downloads / copies in).
# The release's dart-defines are used, except ENABLE_SENTRY (crash reports to the project's tracker).
# Needs: Visual Studio 2022 with the C++ tools; Flutter (the version build.yml pins: a git clone of it is kept in
# the tools folder, in its own folder because of the patched engine); CMake (this PC's, or a portable copy).
# ARM64 isn't built: Flutter only builds Windows ARM64 apps on an ARM64 PC (the project builds it on an ARM64
# runner), and this PC's Visual Studio has no ARM64 C++ tools either.
# Usage: build.cmd [-Version <x.y.z>] [-KeepWork] [-WorkDir <folder>]
# ---------------------------------------------------------------------------------------------
# Flutter and CMake helpers (the same in LocalSend's build.ps1)
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

# ---------------------------------------------------------------------------------------------
# Plezy
# ---------------------------------------------------------------------------------------------

$repo = 'edde746/plezy'
$tag = if ($Version) { $Version -replace '^v' } else { Get-LatestGitHubTag $repo }
$work = Start-Build -Name 'Plezy' -NeedGB 8
$src = Join-Path $work 'src'
Get-GitSource "https://github.com/$repo.git" $tag $src

Use-VisualStudio -Arch x64 -Version '[17.0,18.0)' -Components 'Microsoft.VisualStudio.Component.VC.Tools.x86.x64' | Out-Null

# Flutter (the workflow's FLUTTER_VERSION), with the patched engine
$workflow = Get-Content -LiteralPath (Join-Path $src '.github\workflows\build.yml') -Raw
$m = [regex]::Match($workflow, 'FLUTTER_VERSION:\s*"?([\w.+-]+)"?')
if (-not $m.Success) { throw "Couldn't read FLUTTER_VERSION from .github\workflows\build.yml" }
$flutterVersion = $m.Groups[1].Value
$flutter = Use-Flutter $flutterVersion -Folder "flutter-$flutterVersion-plezy"

Push-Location -LiteralPath $src
try {
    Invoke-Checked $flutter pub get --enforce-lockfile --no-example --suppress-analytics
    Invoke-Checked $flutter precache --windows --suppress-analytics
    Say 'Installing the project''s patched Flutter engine...'
    Invoke-Checked powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $src 'windows\tool\install-patched-engine.ps1')
    $commit = (& (Get-Git) rev-parse HEAD | Out-String).Trim()
}
finally { Pop-Location }

Say ''
Say 'Building Plezy...'
$buildArgs = @('--dart-define=ENABLE_UPDATE_CHECK=true', "--dart-define=GIT_COMMIT=$commit", '--dart-define=SENTRY_ENVIRONMENT=github',
    '--dart-define=ENABLE_DONATIONS=true', '--dart-define=SENTRY_DIST=github-windows-x64', '--dart-define=SUPPORTER_MODE=msstore',
    "--split-debug-info=$(Join-Path $work 'debug-info\windows-x64')")
Invoke-FlutterBuildWindows -Flutter $flutter -ProjectDir $src -Arch x64 -BuildArgs $buildArgs

# (the workflow's check of the bundle)
$out = Join-Path $src 'build\windows\x64\runner\Release'
$missing = @('plezy.exe', 'flutter_windows.dll', 'sqlite3.dll', 'libmpv-2.dll', 'data\app.so', 'data\icudtl.dat', 'data\flutter_assets\NativeAssetsManifest.json', 'msvcp140.dll', 'vcruntime140.dll') |
    Where-Object { -not (Test-Path -LiteralPath (Join-Path $out $_)) }
if ($missing) { throw "The build is missing: $($missing -join ', ')" }

Publish-Build -From $out -Arch x64 -Version $tag -Note "Source: https://github.com/$repo, tag $tag (Flutter $flutterVersion with the project's patched engine)."
Complete-Build