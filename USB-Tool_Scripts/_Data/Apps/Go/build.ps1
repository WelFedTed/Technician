param([string]$Version, [string]$WorkDir, [switch]$KeepWork, [switch]$Yes)
. "$PSScriptRoot\..\_Build-App.ps1"
trap { Stop-Build $_ }

# Builds the Go toolchain from source (the release's source archive from go.dev/dl) into Built\x64, Built\x86 and
# Built\ARM64, the way the official zips are made: src\make.bat -distpack (cmd/distpack), bootstrapped with an
# installed Go; each Built folder holds what the official go<version>.windows-<arch>.zip has in its go folder
# Needs: Go to bootstrap with (this PC's when new enough, otherwise a portable copy is downloaded)
# Usage: build.cmd [-Version <1.x.y>] [-KeepWork] [-WorkDir <folder>]

$goVersion = if ($Version) { 'go' + ($Version -replace '^go') } else { (Get-Text 'https://go.dev/dl/?mode=json' | ConvertFrom-Json)[0].version }
$work = Start-Build -Name 'Go' -NeedGB 3

$archive = Join-Path $work "$goVersion.src.tar.gz"
Say "Getting the source ($goVersion)..."
Get-File "https://go.dev/dl/$goVersion.src.tar.gz" $archive
Expand-Archive7 $archive (Join-Path $work 'src')
$goroot = Join-Path $work 'src\go'
if (-not (Test-Path -LiteralPath (Join-Path $goroot 'src\make.bat'))) { throw "The source archive has no go\src\make.bat" }

# (the bootstrap Go: the version the new one needs is checked by make.bat itself)
Use-Tool go -Version '1.22'
$env:GOROOT_BOOTSTRAP = (& go env GOROOT).Trim()
$env:GOTOOLCHAIN = 'local'
foreach ($v in 'GOROOT', 'GOPATH', 'GOFLAGS', 'GOBIN', 'GOEXPERIMENT', 'CGO_ENABLED') { Remove-Item "Env:$v" -ErrorAction SilentlyContinue }
$env:GOMAXPROCS = '4'

Push-Location -LiteralPath (Join-Path $goroot 'src')
try {
    foreach ($arch in @(@{ Go = 'amd64'; Folder = 'x64' }, @{ Go = '386'; Folder = 'x86' }, @{ Go = 'arm64'; Folder = 'ARM64' })) {
        Say "Building $goVersion for $($arch.Folder)..."
        $env:GOOS = 'windows'; $env:GOARCH = $arch.Go
        Invoke-Checked cmd.exe /d /c "`"$(Join-Path $goroot 'src\make.bat')`" -distpack"
        $zip = Join-Path $goroot "pkg\distpack\$goVersion.windows-$($arch.Go).zip"
        if (-not (Test-Path -LiteralPath $zip)) { throw "make.bat didn't make $zip" }
        $out = Join-Path $work "out\$($arch.Folder)"
        [IO.Compression.ZipFile]::ExtractToDirectory($zip, $out)
        Publish-Build -From (Join-Path $out 'go') -Arch $arch.Folder -Version ($goVersion -replace '^go') -Note "Source: https://go.dev/dl/$goVersion.src.tar.gz (make.bat -distpack, bootstrapped with $((& (Join-Path $env:GOROOT_BOOTSTRAP 'bin\go.exe') version)))"
    }
}
finally { Pop-Location }
Complete-Build
