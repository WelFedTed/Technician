param([string]$Version, [string]$WorkDir, [switch]$KeepWork, [switch]$Yes)
. "$PSScriptRoot\..\_Build-App.ps1"
trap { Stop-Build $_ }

# Builds fzf from source (github.com/junegunn/fzf) into Built\x64 and Built\ARM64, the way its releases are built
# (GoReleaser's .goreleaser.yml: Go without cgo, -trimpath, version and commit stamped in: fzf.exe)
# Needs: Go (this PC's when new enough for fzf's go.mod, otherwise a portable copy is downloaded)
# Usage: build.cmd [-Version <x.y.z>] [-KeepWork] [-WorkDir <folder>]

$repo = 'junegunn/fzf'
$tag = if ($Version) { 'v' + ($Version -replace '^v') } else { Get-LatestGitHubTag $repo }
$ver = $tag -replace '^v'
$work = Start-Build -Name 'fzf' -NeedGB 1
$src = Join-Path $work 'src'
Get-GitSource "https://github.com/$repo.git" $tag $src
$commit = (& (Get-Git) -C $src rev-parse --short HEAD).Trim()

# (the Go version fzf's go.mod asks for)
$goLine = Select-String -LiteralPath (Join-Path $src 'go.mod') -Pattern '^go (\d+\.\d+)' | Select-Object -First 1
Use-Tool go -Version $(if ($goLine) { $goLine.Matches[0].Groups[1].Value })
$env:CGO_ENABLED = '0'; $env:GOOS = 'windows'; $env:GOTOOLCHAIN = 'auto'

Push-Location -LiteralPath $src
try {
    Invoke-Checked go mod download
    foreach ($arch in @(@{ Go = 'amd64'; Folder = 'x64' }, @{ Go = 'arm64'; Folder = 'ARM64' })) {
        Say "Building fzf for $($arch.Folder)..."
        $env:GOARCH = $arch.Go
        $out = Join-Path $work "out\$($arch.Folder)"
        Invoke-Checked go build -buildvcs=false -trimpath -ldflags "-s -w -X main.version=$ver -X main.revision=$commit" -o (Join-Path $out 'fzf.exe') .
        Publish-Build -From $out -Arch $arch.Folder -Version $ver -Note "Source: https://github.com/$repo, tag $tag ($commit)"
    }
}
finally { Pop-Location }
Complete-Build
