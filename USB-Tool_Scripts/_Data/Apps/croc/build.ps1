# Builds croc from source (github.com/schollz/croc) into Built\x64, Built\x86 and Built\ARM64, the way its
# releases are built (Go, without cgo: croc.exe and croc-update.exe)
# Needs: Go (this PC's when new enough for croc's go.mod, otherwise a portable copy is downloaded)
# Usage: build.cmd [-Version <x.y.z>] [-KeepWork] [-WorkDir <folder>]
param([string]$Version, [string]$WorkDir, [switch]$KeepWork, [switch]$Yes)
. "$PSScriptRoot\..\_Build-App.ps1"
trap { Stop-Build $_ }

$repo = 'schollz/croc'
$tag = if ($Version) { 'v' + ($Version -replace '^v') } else { Get-LatestGitHubTag $repo }
$work = Start-Build -Name 'croc' -NeedGB 1
$src = Join-Path $work 'src'
Get-GitSource "https://github.com/$repo.git" $tag $src

# (the Go version croc's go.mod asks for)
$goLine = Select-String -LiteralPath (Join-Path $src 'go.mod') -Pattern '^go (\d+\.\d+)' | Select-Object -First 1
Use-Tool go -Version $(if ($goLine) { $goLine.Matches[0].Groups[1].Value })
$env:CGO_ENABLED = '0'; $env:GOOS = 'windows'; $env:GOTOOLCHAIN = 'auto'

Push-Location -LiteralPath $src
try {
    foreach ($arch in @(@{ Go = 'amd64'; Folder = 'x64' }, @{ Go = '386'; Folder = 'x86' }, @{ Go = 'arm64'; Folder = 'ARM64' })) {
        Say "Building croc for $($arch.Folder)..."
        $env:GOARCH = $arch.Go
        $out = Join-Path $work "out\$($arch.Folder)"
        Invoke-Checked go build -buildvcs=false -trimpath -tags 'netgo,osusergo' -ldflags '-s -w -buildid=' -o (Join-Path $out 'croc.exe') .
        Invoke-Checked go build -buildvcs=false -trimpath -tags 'netgo,osusergo' -ldflags '-s -w -buildid=' -o (Join-Path $out 'croc-update.exe') ./cmd/croc-update
        Publish-Build -From $out -Arch $arch.Folder -Version ($tag -replace '^v') -Note "Source: https://github.com/$repo, tag $tag"
    }
}
finally { Pop-Location }
Complete-Build
