param([string]$Version, [string]$WorkDir, [switch]$KeepWork, [switch]$Yes)
. "$PSScriptRoot\..\..\_Build-App.ps1"
trap { Stop-Build $_ }

# Builds File Drop from source (github.com/WelFedTed/file-drop) into Built\x64, the way its README's "Releasing"
# section builds a release: file-drop.exe (current Go) and file-drop-win7.exe (Go 1.20.14, the last Go for
# Windows 7 / 8, with go120.mod), each with its Windows resource from tools/mksyso
# Needs: Go (this PC's when new enough for go.mod, otherwise a portable copy is downloaded) and Go 1.20.14 (a
# portable copy is downloaded into the tools folder)
# Usage: build.cmd [-Version <x.y.z>] [-KeepWork] [-WorkDir <folder>]

$repo = 'WelFedTed/file-drop'
$tag = if ($Version) { 'v' + ($Version -replace '^v') } else { Get-LatestGitHubTag $repo }
$work = Start-Build -Name 'File Drop' -NeedGB 1
$src = Join-Path $work 'src'
Get-GitSource "https://github.com/$repo.git" $tag $src

$goLine = Select-String -LiteralPath (Join-Path $src 'go.mod') -Pattern '^go (\d+\.\d+)' | Select-Object -First 1
Use-Tool go -Version $(if ($goLine) { $goLine.Matches[0].Groups[1].Value })
$env:GOTOOLCHAIN = 'auto'; $env:GOOS = 'windows'; $env:GOARCH = 'amd64'; $env:CGO_ENABLED = '0'

# Go 1.20.14 for the Windows 7 build, in the tools folder
$go120Dir = Join-Path $script:toolsDir 'go1.20.14'
$go120 = Join-Path $go120Dir 'go\bin\go.exe'
if (-not (Test-Path -LiteralPath $go120)) {
    Say 'Getting a portable Go 1.20.14 (for the Windows 7 build)...'
    $zip = Join-Path $script:toolsDir 'go1.20.14.windows-amd64.zip'
    Get-File 'https://go.dev/dl/go1.20.14.windows-amd64.zip' $zip
    [IO.Compression.ZipFile]::ExtractToDirectory($zip, $go120Dir); Remove-Item -LiteralPath $zip
}

$out = Join-Path $work 'out'
Push-Location -LiteralPath $src
try {
    Say 'Building file-drop.exe...'
    Invoke-Checked go run ./tools/mksyso
    Invoke-Checked go build -trimpath -ldflags '-s -w' -o (Join-Path $out 'file-drop.exe') .

    Say 'Building file-drop-win7.exe (Go 1.20.14)...'
    Invoke-Checked go run ./tools/mksyso -name file-drop-win7.exe
    $saved = $env:GOTOOLCHAIN; $env:GOTOOLCHAIN = 'local'
    try { Invoke-Checked $go120 build '-modfile=go120.mod' -trimpath -ldflags '-s -w -X main.releaseAsset=file-drop-win7.exe' -o (Join-Path $out 'file-drop-win7.exe') . }
    finally { $env:GOTOOLCHAIN = $saved }
}
finally { Pop-Location }
Publish-Build -From $out -Arch 'x64' -Version ($tag -replace '^v') -Note "Source: https://github.com/$repo, tag $tag"
Complete-Build
