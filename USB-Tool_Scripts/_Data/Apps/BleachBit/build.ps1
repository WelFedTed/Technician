param([string]$Version, [string]$WorkDir, [switch]$KeepWork, [switch]$Yes)
. "$PSScriptRoot\..\_Build-App.ps1"
trap { Stop-Build $_ }

# Builds BleachBit from source (github.com/bleachbit/bleachbit) into Built\x86, the way its Windows CI job makes the
# release's portable zip: windows\python-gtk3-install.ps1 (the project's 32-bit Python 3.12 + GTK 3 bundle and
# PyGObject wheel, checked against their SHA-256, plus the pip requirements; psutil is compiled with Visual C++),
# "make -C po local" (translations, with MSYS2's make and gettext), then "python -m windows.setup" (py2exe):
# the BleachBit-Portable folder (bleachbit.exe, bleachbit_console.exe, GTK, BleachBit.ini) the portable zip holds.
# Differences: no installer (NSIS isn't used), not code-signed, and the step that starts the built GUI to check it
# (--gui --exit) is skipped.
# Needs: Visual Studio 2022 with the C++ tools (for psutil), a portable MSYS2 (make, gettext) and 7-Zip (this PC's
# or a portable 7za), all set up by the build; Python and GTK come from the project's own bundle
# (Python can't load its DLLs from paths over 260 characters: a -WorkDir needs to be a short path)
# Usage: build.cmd [-Version <x.y.z>] [-KeepWork] [-WorkDir <folder>]

$repo = 'bleachbit/bleachbit'
$tag = if ($Version) { 'v' + ($Version -replace '^v') } else { Get-LatestGitHubTag $repo -Match '^v[\d.]+$' }
$work = Start-Build -Name 'BleachBit' -NeedGB 4
$src = Join-Path $work 'src'
Get-GitSource "https://github.com/$repo.git" $tag $src
$git = Get-Git

# (the CI's generate-revision action)
$rev = (& $git -C $src rev-parse --short=8 HEAD).Trim()
[IO.File]::WriteAllText((Join-Path $src 'bleachbit\Revision.py'), "revision = `"$rev`"`nbuild_number = `"0`"`n")

# (psutil has no 32-bit wheels, so pip compiles it: 32-bit Visual C++)
Use-VisualStudio -Arch x86 -Version '[17.0,18.0)' -Components 'Microsoft.VisualStudio.Component.VC.Tools.x86.x64' | Out-Null
Use-Msys2 -Packages 'make', 'gettext'
$sevenZip = Get-SevenZip

Push-Location -LiteralPath $src
try {
    Say 'Getting Python, GTK and the Python packages (windows\python-gtk3-install.ps1)...'
    # (GITHUB_ACTIONS: the script then skips installing the Visual C++ runtime on the PC, which the build doesn't need)
    $env:GITHUB_ACTIONS = 'true'; $env:PIP_DISABLE_PIP_VERSION_CHECK = '1'; $env:PIP_NO_INPUT = '1'
    & powershell -NoProfile -ExecutionPolicy Bypass -Command "`$ProgressPreference = 'SilentlyContinue'; & '.\windows\python-gtk3-install.ps1'; exit `$LASTEXITCODE"
    Remove-Item Env:GITHUB_ACTIONS
    $python = Join-Path $src 'vcpkg_installed\x86-windows\tools\python3\python.exe'
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $python)) { throw "windows\python-gtk3-install.ps1 failed (exit code $LASTEXITCODE)" }
    Invoke-Checked $python -c 'import gi, py2exe, win32file, psutil'

    Say 'Making the translations (make -C po local)...'
    Invoke-Msys2 -Env msys -Command 'make -C po local' -Dir $src

    Say 'Building BleachBit (windows.setup, py2exe)...'
    # (= "python -m windows.setup", with 7-Zip's path from this PC and without starting the built GUI)
    $code = "import sys; sys.argv = ['windows/setup.py', 'py2exe']; import windows.setup as s; s.SZ_EXE = r'$sevenZip'; s.assert_execute_console = lambda: None; s.main()"
    Invoke-Checked $python -u -c $code
}
finally { Pop-Location }

$portable = Join-Path $src 'BleachBit-Portable'
if (-not (Test-Path -LiteralPath (Join-Path $portable 'bleachbit.exe'))) { throw "The build didn't make BleachBit-Portable\bleachbit.exe" }
Publish-Build -From $portable -Arch 'x86' -Version ($tag -replace '^v') -Note "Source: https://github.com/$repo, tag $tag ($rev)"
Complete-Build
