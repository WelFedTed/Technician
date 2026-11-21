param([string]$Version, [string]$WorkDir, [switch]$KeepWork, [switch]$Yes)
. "$PSScriptRoot\..\_Build-App.ps1"
trap { Stop-Build $_ }

# Builds ImageMagick 7 from source (github.com/ImageMagick/ImageMagick) into Built\x64 and Built\x86 (and Built\ARM64
# when Visual Studio has its ARM64 C++ tools) like the "portable" Q16-HDRI build of its release workflow
# (.github/workflows/release.yml, windows_portable): magick.exe statically linked (with the static C runtime), its
# .xml config files, sRGB.icc, NOTICE.txt and LICENSE.txt. The release workflow downloads its third-party libraries
# already built (ImageMagick/Dependencies releases); this builds them from source as well, the way the ImageMagick/Windows
# development environment does: the Dependencies repository at the release ImageMagick names, with each library's
# source at the commit its clone-dependencies.sh names, all in one solution made by Configure (/noWizard).
# Differences: Configure itself (the project's solution generator, an MFC program for Visual Studio 2026) is the
# prebuilt Configure.Release.x64.exe from the ImageMagick/Configure release ImageMagick names, as the release
# workflow uses; Visual Studio 2022 (v143) instead of 2026; not code-signed.
# Needs: Visual Studio 2022 with C++ (Configure's own NASM is used for the assembly parts), Git
# Usage: build.cmd [-Version <7.x.y-z>] [-KeepWork] [-WorkDir <folder>]

$repo = 'ImageMagick/ImageMagick'
$tag = if ($Version) { $Version } else { Get-LatestGitHubTag $repo }
# (a short work folder: the libraries' sources and the build go several folders deep)
$work = Start-Build -Name 'ImageMagick' -NeedGB 12
$env:GIT_CONFIG_COUNT = '1'; $env:GIT_CONFIG_KEY_0 = 'core.longpaths'; $env:GIT_CONFIG_VALUE_0 = 'true'
$im = Join-Path $work 'ImageMagick'
Get-GitSource "https://github.com/$repo.git" $tag $im

# the Configure and Dependencies releases this ImageMagick release uses (from its download scripts)
$configureVer = [regex]::Match((Get-Content -LiteralPath (Join-Path $im '.github\build\windows\download-configure.sh') -Raw), 'download_configure\s+"([^"]+)"').Groups[1].Value
$depsVer = [regex]::Match((Get-Content -LiteralPath (Join-Path $im '.github\build\shared\download-dependencies.sh') -Raw), 'download_dependencies\s+"([^"]+)"').Groups[1].Value
if (-not $configureVer -or -not $depsVer) { throw "Couldn't read the Configure / Dependencies versions from ImageMagick's .github\build scripts" }
Say "Configure $configureVer, Dependencies $depsVer"

$configure = Join-Path $work 'Configure'
foreach ($f in 'Configure.Release.x64.exe', 'files.zip') { Get-File "https://github.com/ImageMagick/Configure/releases/download/$configureVer/$f" (Join-Path $configure $f) }
[IO.Compression.ZipFile]::ExtractToDirectory((Join-Path $configure 'files.zip'), $configure)

# the libraries, each at the commit clone-dependencies.sh names (a shallow fetch of that commit instead of its full clone)
$deps = Join-Path $work 'Dependencies'
Get-GitSource 'https://github.com/ImageMagick/Dependencies.git' $depsVer $deps
$cloneScript = Get-Content -LiteralPath (Join-Path $deps 'clone-dependencies.sh') -Raw
$git = Get-Git
$sections = [regex]::Split($cloneScript, '(?m)^(clone_\w+)\(\)')
for ($i = 1; $i -lt $sections.Count; $i += 2) {
    # (clone_dependencies > Dependencies, clone_non_windows_dependencies > NonWindowsDependencies; the optional ones
    # (fftw, flif, jbig) are only used with /includeOptional)
    $folder = switch ($sections[$i]) { 'clone_dependencies' { 'Dependencies' } 'clone_non_windows_dependencies' { 'NonWindowsDependencies' } default { $null } }
    if (-not $folder) { continue }
    foreach ($m in [regex]::Matches($sections[$i + 1], "clone\s+'([^']+)'\s+'([0-9a-f]{40})'")) {
        $name = $m.Groups[1].Value; $commit = $m.Groups[2].Value
        $dir = Join-Path $deps "$folder\$name"
        Say "Getting $name ($($commit.Substring(0, 10)))..."
        Invoke-Checked $git init -q $dir
        Invoke-Checked $git -C $dir fetch -q --depth 1 "https://github.com/ImageMagick/$name.git" $commit
        Invoke-Checked $git -C $dir -c advice.detachedHead=false checkout -q FETCH_HEAD
    }
}

$env:PATH = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer;$env:PATH"
$env:MSBUILDDISABLENODEREUSE = '1'
$cleanEnv = @{}; Get-ChildItem Env: | ForEach-Object { $cleanEnv[$_.Name] = $_.Value }
function Reset-Env { Get-ChildItem Env: | Where-Object { -not $cleanEnv.ContainsKey($_.Name) } | ForEach-Object { Remove-Item -LiteralPath "Env:$($_.Name)" }; foreach ($k in $cleanEnv.Keys) { Set-Item -LiteralPath "Env:$k" -Value $cleanEnv[$k] } }
function Test-VSComponent([string[]]$Components) {
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    return [bool](& $vswhere -version '[17.0,18.0)' -products * -requires $Components -property installationPath)
}

$ver = $tag
foreach ($arch in @(
        @{ VS = 'x64'; Folder = 'x64'; Platform = 'x64' },
        @{ VS = 'x86'; Folder = 'x86'; Platform = 'x86' },
        @{ VS = 'arm64'; Folder = 'ARM64'; Platform = 'arm64'; Needs = 'Microsoft.VisualStudio.Component.VC.Tools.ARM64' })) {
    if ($arch.Needs -and -not (Test-VSComponent $arch.Needs)) { Say "Skipping $($arch.Folder): Visual Studio 2022 doesn't have $($arch.Needs)"; continue }
    Reset-Env
    Use-VisualStudio -Arch $arch.VS -Version '[17.0,18.0)' -Components (@('Microsoft.VisualStudio.Component.VC.Tools.x86.x64', 'Microsoft.VisualStudio.Component.Windows11SDK.26100') + @($arch.Needs | Where-Object { $_ })) | Out-Null
    # (a clean solution and Artifacts folder for each architecture)
    Get-ChildItem -LiteralPath $work -Filter '*.sln' | Remove-Item -Force
    if (Test-Path -LiteralPath (Join-Path $work 'Artifacts')) { Remove-Item -LiteralPath (Join-Path $work 'Artifacts') -Recurse -Force }
    Say "Configuring ImageMagick $tag for $($arch.Folder) (Q16 HDRI, static)..."
    Push-Location -LiteralPath $configure
    try { Invoke-Checked (Join-Path $configure 'Configure.Release.x64.exe') /noWizard /VS2022 /hdri /Q16 "/$($arch.Platform)" /static /linkRuntime /includeNonWindows }
    finally { Pop-Location }
    $sln = Get-ChildItem -LiteralPath $work -Filter '*.sln' | Select-Object -First 1
    if (-not $sln) { throw "Configure didn't make a solution in $work" }
    Say "Building $($sln.Name)..."
    # (the projects compile with /MP, so CL_MPCount=1 keeps it to 4 compilers at once with /m:4)
    Invoke-Checked msbuild $sln.FullName /nologo /verbosity:minimal /m:4 /p:CL_MPCount=1 /t:Build /p:Configuration=Release "/p:Platform=$($arch.Platform)"

    # the portable layout (the release workflow's "Copy Files" step)
    $bin = Join-Path $work 'Artifacts\bin'
    $out = Join-Path $work "out\$($arch.Folder)"
    New-Item -ItemType Directory -Path $out -Force | Out-Null
    Copy-Item -Path (Join-Path $bin '*.exe'), (Join-Path $bin '*.xml') -Destination $out
    Copy-Item -LiteralPath (Join-Path $bin 'sRGB.icc') -Destination $out
    Copy-Item -LiteralPath (Join-Path $work 'Artifacts\NOTICE.txt') -Destination $out
    if (Test-Path -LiteralPath (Join-Path $im 'ChangeLog.md')) { Copy-Item -LiteralPath (Join-Path $im 'ChangeLog.md') -Destination $out }
    Copy-Item -LiteralPath (Join-Path $im 'LICENSE') -Destination (Join-Path $out 'LICENSE.txt')
    if (-not (Test-Path -LiteralPath (Join-Path $out 'magick.exe'))) { throw "The build didn't make magick.exe" }
    Publish-Build -From $out -Arch $arch.Folder -Version $ver -Note "Source: https://github.com/$repo, tag $tag (portable Q16-HDRI static; Dependencies $depsVer built from source; Configure $configureVer)"
}
Complete-Build
