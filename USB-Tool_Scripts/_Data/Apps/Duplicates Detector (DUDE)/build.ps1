param([string]$Version, [string]$WorkDir, [switch]$KeepWork, [switch]$Yes)
. "$PSScriptRoot\..\_Build-App.ps1"
trap { Stop-Build $_ }

# Builds DUDE (Duplicates Detector) from source (github.com/PJDude/dude) into Built\x64, the way its Windows CI job
# does (pip install -r requirements.txt, icons.convert.bat, pyinstaller.run.bat): dude.exe, dudecmd.exe and their
# internal folder, the same as the release's dude.v<version>.win.zip.
# The project's version.py makes the version from the build time, so the release tag's version is used instead.
# Needs: Python 3.14 with tkinter (a portable copy from python-build-standalone, kept in the tools folder) and Git
# Usage: build.cmd [-Version <2.x.y>] [-KeepWork] [-WorkDir <folder>]

$repo = 'PJDude/dude'
$tag = if ($Version) { 'v' + ($Version -replace '^v') } else { Get-LatestGitHubTag $repo }
$ver = $tag -replace '^v'
$work = Start-Build -Name 'DUDE' -NeedGB 3
$src = Join-Path $work 'src'
Get-GitSource "https://github.com/$repo.git" $tag $src

# Python 3.14 as its CI uses, with tkinter: python-build-standalone's install_only build (NuGet's Python, which
# Use-Tool python gets, has no tkinter)
$pyDir = Join-Path $script:toolsDir 'python-3.14-standalone'
if (-not (Test-Path -LiteralPath "$pyDir\python\python.exe")) {
    Say 'Getting a portable Python 3.14 with tkinter (python-build-standalone)...'
    $release = Get-Text 'https://api.github.com/repos/astral-sh/python-build-standalone/releases/latest' | ConvertFrom-Json
    $asset = $release.assets | Where-Object { $_.name -match '^cpython-3\.14\.\d+\+\d+-x86_64-pc-windows-msvc-install_only\.tar\.gz$' } | Select-Object -First 1
    if (-not $asset) { throw "Couldn't find a Python 3.14 Windows build in python-build-standalone's latest release" }
    $archive = Join-Path $script:toolsDir $asset.name
    Get-File $asset.browser_download_url $archive
    Expand-Archive7 $archive $pyDir
    Remove-Item -LiteralPath $archive
}
$venv = Join-Path $work 'venv'
Invoke-Checked "$pyDir\python\python.exe" -m venv $venv
Add-ToPath "$venv\Scripts"
$env:PIP_CACHE_DIR = Join-Path $script:toolsDir 'pip-cache'
$env:PIP_DISABLE_PIP_VERSION_CHECK = '1'

Push-Location -LiteralPath $src
try {
    Say 'Installing the requirements (pip)...'
    Invoke-Checked "$venv\Scripts\python.exe" -m pip install --upgrade pip
    Invoke-Checked "$venv\Scripts\python.exe" -m pip install -r requirements.txt

    # (version.gen.bat's files, with the tag's version)
    $srcDir = Join-Path $src 'src'
    [IO.File]::WriteAllText((Join-Path $srcDir 'version.txt'), "v$ver")
    foreach ($name in 'dude', 'dudecmd') {
        $template = [IO.File]::ReadAllText((Join-Path $srcDir "version.pi.template.$name.txt"))
        [IO.File]::WriteAllText((Join-Path $srcDir "version.pi.$name.txt"), $template.Replace('VER_TO_REPLACE', $ver))
    }

    Say 'Converting the icons (icons.convert.bat)...'
    Invoke-Checked cmd.exe /d /c (Join-Path $src 'scripts\icons.convert.bat')
    Say 'Building with PyInstaller (pyinstaller.run.bat)...'
    Invoke-Checked cmd.exe /d /c (Join-Path $src 'scripts\pyinstaller.run.bat')
}
finally { Pop-Location }

$out = Join-Path $src 'build-pyinstaller\dude'
if (-not (Test-Path -LiteralPath (Join-Path $out 'dude.exe')) -or -not (Test-Path -LiteralPath (Join-Path $out 'dudecmd.exe'))) { throw "The build didn't make dude.exe and dudecmd.exe" }
Publish-Build -From $out -Arch 'x64' -Version $ver -Note "Source: https://github.com/$repo, tag $tag"
Complete-Build
