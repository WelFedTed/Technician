param([string]$Version, [string]$WorkDir, [switch]$KeepWork, [switch]$Yes)
. "$PSScriptRoot\..\_Build-App.ps1"
trap { Stop-Build $_ }

# Builds PhotoRec (and QPhotoRec, with TestDisk) from source into Built\x64: PhotoRec comes in the same source and
# the same official zip as TestDisk, so this runs TestDisk's build.ps1 (_Data\Apps\TestDisk), with this app's Built
# folder as where the build goes. See that script for what it builds, how, and what it needs.
# Needs: the TestDisk app folder beside this one; a portable MSYS2 (downloaded into the tools folder when missing)
# Usage: build.cmd [-Version <x.y>] [-KeepWork] [-WorkDir <folder>]

$testdisk = Join-Path (Split-Path -Parent $PSScriptRoot) 'TestDisk\build.ps1'
if (-not (Test-Path -LiteralPath $testdisk)) { Fail "PhotoRec is built by TestDisk's build.ps1, which isn't here: $testdisk" }

$pass = @()
if ($Version) { $pass += @('-Version', $Version) }
if ($WorkDir) { $pass += @('-WorkDir', $WorkDir) }
if ($KeepWork) { $pass += '-KeepWork' }
if ($Yes) { $pass += '-Yes' }
$env:TESTDISK_BUILD_NAME = 'PhotoRec'
$env:TESTDISK_BUILT_DIR = $PSScriptRoot
& powershell -NoProfile -ExecutionPolicy Bypass -File $testdisk @pass
exit $LASTEXITCODE
