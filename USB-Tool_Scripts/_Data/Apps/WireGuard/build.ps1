param([string]$Version, [string]$WorkDir, [switch]$KeepWork, [switch]$Yes)
. "$PSScriptRoot\..\_Build-App.ps1"
trap { Stop-Build $_ }

# Builds WireGuard for Windows from source (git.zx2c4.com/wireguard-windows) into Built\x64, Built\x86 and
# Built\ARM64 with the project's own build.bat, which gets its pinned toolchain itself (Go, llvm-mingw, make,
# ImageMagick, wireguard-tools and the signed wireguard-nt driver, checked against their SHA-256) into the
# source's .deps folder: wireguard.exe and wg.exe, the two programs the official MSI installs (not the MSI)
# Needs: nothing installed (build.bat downloads its own toolchain)
# Usage: build.cmd [-Version <x.y.z>] [-KeepWork] [-WorkDir <folder>]

# (the newest version on the download page update.cmd uses)
if (-not $Version) {
    $page = Get-Text 'https://download.wireguard.com/windows-client/'
    $Version = [regex]::Matches($page, 'wireguard-amd64-([\d.]+)\.msi') | ForEach-Object { $_.Groups[1].Value } |
        Sort-Object { [version]($_ + $(if ($_ -notmatch '\.') { '.0' })) } | Select-Object -Last 1
    if (-not $Version) { throw "Couldn't find the latest version on download.wireguard.com" }
}
$tag = 'v' + ($Version -replace '^v')
$work = Start-Build -Name 'WireGuard' -NeedGB 3
$src = Join-Path $work 'src'
Get-GitSource 'https://git.zx2c4.com/wireguard-windows' $tag $src

Say 'Running build.bat (it downloads its toolchain first)...'
# (build.bat runs make with -j%NUMBER_OF_PROCESSORS%: kept to 4 here)
$savedProcs = $env:NUMBER_OF_PROCESSORS; $env:NUMBER_OF_PROCESSORS = '4'
foreach ($v in 'GOROOT', 'GOPATH', 'GOFLAGS', 'GOTOOLCHAIN', 'GOARCH', 'GOOS', 'CGO_ENABLED') { Remove-Item "Env:$v" -ErrorAction SilentlyContinue }
try { Invoke-Checked cmd.exe /d /c "`"$(Join-Path $src 'build.bat')`"" }
finally { $env:NUMBER_OF_PROCESSORS = $savedProcs }

foreach ($arch in @(@{ Dir = 'amd64'; Folder = 'x64' }, @{ Dir = 'x86'; Folder = 'x86' }, @{ Dir = 'arm64'; Folder = 'ARM64' })) {
    Publish-Build -From (Join-Path $src $arch.Dir) -Arch $arch.Folder -Version ($tag -replace '^v') -Files 'wireguard.exe', 'wg.exe' -Note "Source: https://git.zx2c4.com/wireguard-windows, tag $tag (build.bat)"
}
Complete-Build
