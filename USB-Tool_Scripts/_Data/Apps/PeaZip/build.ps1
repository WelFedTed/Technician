param([string]$Version, [string]$WorkDir, [switch]$KeepWork, [switch]$Yes)
. "$PSScriptRoot\..\_Build-App.ps1"
trap { Stop-Build $_ }

# Builds PeaZip from source (github.com/peazip/PeaZip) into Built\x64, the way its CI workflow builds it
# (.github/workflows/make.pas: lazbuild --add-package-link for each .lpk, then lazbuild --build-all for each .lpi,
# with the Lazarus version .github/workflows/setup.ps1 names), laid out like the portable zip: peazip.exe, pea.exe,
# dragdropfilesdll.dll and res\ (the helper programs, 7z, zstd, brotli..., ship prebuilt in the source's res folder).
# Lazarus only comes as an installer, so its files are unpacked from it with innoextract instead of running it.
# Only x64: the 32-bit package's res\bin holds 32-bit helper programs that aren't in the source.
# Needs: Lazarus with Free Pascal (unpacked into the tools folder) and innoextract (downloaded)
# Usage: build.cmd [-Version <x.y.z>] [-KeepWork] [-WorkDir <folder>]

$repo = 'peazip/PeaZip'
$tag = if ($Version) { $Version -replace '^v' } else { Get-LatestGitHubTag $repo }
$work = Start-Build -Name 'PeaZip' -NeedGB 3
$src = Join-Path $work 'src'
# (some of res\share's file names are long: git's core.longpaths, set through the environment)
$env:GIT_CONFIG_COUNT = '1'; $env:GIT_CONFIG_KEY_0 = 'core.longpaths'; $env:GIT_CONFIG_VALUE_0 = 'true'
Get-GitSource "https://github.com/$repo.git" $tag $src -Submodules

# Lazarus: the installer the CI uses (its URL from setup.ps1), unpacked with innoextract
$setup = [IO.File]::ReadAllText((Join-Path $src '.github\workflows\setup.ps1'))
$lazUrl = [regex]::Match($setup, "https://download\.lazarus-ide\.org/[^'`"]+\.exe").Value
if (-not $lazUrl) { throw "Couldn't find the Lazarus download in .github\workflows\setup.ps1" }
$lazName = [IO.Path]::GetFileNameWithoutExtension([Uri]::UnescapeDataString($lazUrl))
$lazDir = Join-Path $script:toolsDir $lazName
if (-not (Test-Path -LiteralPath (Join-Path $lazDir 'lazbuild.exe'))) {
    $inno = Join-Path $script:toolsDir 'innoextract\innoextract.exe'
    if (-not (Test-Path -LiteralPath $inno)) {
        Say 'Getting innoextract...'
        $zip = Join-Path $script:toolsDir 'innoextract.zip'
        Get-File 'https://github.com/dscharrer/innoextract/releases/download/1.9/innoextract-1.9-windows.zip' $zip
        [IO.Compression.ZipFile]::ExtractToDirectory($zip, (Join-Path $script:toolsDir 'innoextract')); Remove-Item -LiteralPath $zip
    }
    Say "Getting $lazName (unpacked, not installed)..."
    $exe = Join-Path $work "$lazName.exe"
    Get-File $lazUrl $exe
    $unpack = Join-Path $work 'lazarus-unpack'
    # (everything except Free Pascal's own source, which the build doesn't need and whose deepest example folders
    # can be over Windows' 260-character limit: innoextract has no exclude option, so the rest is listed as includes)
    $names = & $inno --list $exe | ForEach-Object { if ($_ -match '"(app\\[^"]+)"') { $Matches[1] } }
    $includes = $names | ForEach-Object {
        $p = $_ -split '\\'
        if ($p.Count -ge 4 -and $p[1] -eq 'fpc') { if ($p.Count -gt 4 -and $p[3] -ne 'source') { ($p[0..3] -join '\') } elseif ($p.Count -eq 4) { ($p[0..3] -join '\') } }
        elseif ($p.Count -ge 2) { ($p[0..1] -join '\') }
    } | Sort-Object -Unique
    $incArgs = @($includes | ForEach-Object { '-I'; $_ })
    & $inno --silent --extract @incArgs --output-dir $unpack $exe
    if (-not (Test-Path -LiteralPath (Join-Path $unpack 'app\lazbuild.exe'))) { throw "innoextract couldn't unpack $lazName (exit code $LASTEXITCODE)" }
    Move-Item -LiteralPath (Join-Path $unpack 'app') -Destination $lazDir
    Remove-Item -LiteralPath $exe
}
# (the installer writes fpc.cfg when it runs; unpacked, it's made here with fpcmkcfg, as the installer does)
$fpcBin = Get-ChildItem -LiteralPath (Join-Path $lazDir 'fpc') -Recurse -Filter 'fpc.exe' | Where-Object { $_.Directory.Name -eq 'x86_64-win64' } | Select-Object -First 1
if (-not $fpcBin) { throw "No fpc.exe in $lazDir\fpc" }
$fpcBase = $fpcBin.Directory.Parent.Parent.FullName
$fpcCfg = Join-Path $fpcBin.DirectoryName 'fpc.cfg'
if (-not (Test-Path -LiteralPath $fpcCfg)) {
    Invoke-Checked (Join-Path $fpcBin.DirectoryName 'fpcmkcfg.exe') -d "basepath=$fpcBase" -o $fpcCfg
}
Add-ToPath $fpcBin.DirectoryName
Add-ToPath $lazDir
# (lazbuild keeps its settings in the work folder, not the user's profile)
$pcp = Join-Path $work 'lazarus-config'
$lazArgs = @("--primary-config-path=$pcp", "--lazarusdir=$lazDir", "--compiler=$($fpcBin.FullName)", '--cpu=x86_64', '--os=win64', '--max-process-count=1')
# (one package at a time: with several, lazbuild started a package before the one it needs had finished)

Push-Location -LiteralPath $src
try {
    foreach ($lpk in Get-ChildItem -LiteralPath $src -Recurse -Filter '*.lpk') {
        Say "Adding package $($lpk.Name)..."
        Invoke-Checked lazbuild.exe @lazArgs --add-package-link $lpk.FullName
    }
    foreach ($lpi in 'peazip-sources\dev\dragdropfilesdll.src\dragdropfilesdll.lpi', 'peazip-sources\dev\project_pea.lpi', 'peazip-sources\dev\project_peach.lpi') {
        Say "Building $(Split-Path -Leaf $lpi)..."
        Invoke-Checked lazbuild.exe @lazArgs --build-all --recursive --no-write-project (Join-Path $src $lpi)
    }
}
finally { Pop-Location }

# the portable layout
$out = Join-Path $work 'out'
New-Item -ItemType Directory -Path $out -Force | Out-Null
$dev = Join-Path $src 'peazip-sources\dev'
foreach ($f in @((Join-Path $dev 'peazip.exe'), (Join-Path $dev 'pea.exe'), (Join-Path $dev 'dragdropfilesdll.src\dragdropfilesdll.dll'))) {
    if (-not (Test-Path -LiteralPath $f)) { throw "The build didn't make $f" }
    Copy-Item -LiteralPath $f -Destination $out
}
Copy-Item -LiteralPath (Join-Path $src 'peazip-sources\res') -Destination (Join-Path $out 'res') -Recurse
Publish-Build -From $out -Arch 'x64' -Version $tag -Note "Source: https://github.com/$repo, tag $tag ($lazName)"
Complete-Build
