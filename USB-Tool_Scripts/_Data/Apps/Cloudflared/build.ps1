param([string]$Version, [string]$WorkDir, [switch]$KeepWork, [switch]$Yes)
. "$PSScriptRoot\..\_Build-App.ps1"
trap { Stop-Build $_ }

# Builds cloudflared from source (github.com/cloudflare/cloudflared) into Built\x64 and Built\x86, the way its
# Windows releases are built (.ci/scripts/windows/builds.ps1 running "make cloudflared": go build -mod=readonly
# with the version and build time stamped in, the exact Go version from go.mod): cloudflared.exe
# (Its CI builds the x64 exe with cgo on; nothing in cloudflared uses cgo on Windows, so this builds both without
# it and doesn't need a C compiler.)
# Needs: Go (this PC's when new enough, otherwise a portable copy is downloaded; Go itself fetches the exact
# version go.mod names when it's different)
# Usage: build.cmd [-Version <yyyy.m.n>] [-KeepWork] [-WorkDir <folder>]

$repo = 'cloudflare/cloudflared'
$tag = if ($Version) { $Version -replace '^v' } else { Get-LatestGitHubTag $repo }
$work = Start-Build -Name 'Cloudflared' -NeedGB 2
$src = Join-Path $work 'src'
Get-GitSource "https://github.com/$repo.git" $tag $src
$git = Get-Git

# (the Makefile's VERSION and DATE)
$ver = (& $git -C $src describe --tags --always --match '[0-9][0-9][0-9][0-9].*.*').Trim()
$env:TZ = 'UTC'
$date = (& $git -C $src log -1 --format=%ad --date=format-local:'%Y-%m-%dT%H:%M UTC').Trim()
Remove-Item Env:TZ

$goLine = Select-String -LiteralPath (Join-Path $src 'go.mod') -Pattern '^go (\d+\.\d+(\.\d+)?)' | Select-Object -First 1
$goVer = if ($goLine) { $goLine.Matches[0].Groups[1].Value }
Use-Tool go -Version $goVer
$env:GOTOOLCHAIN = if ($goVer) { "go$goVer" } else { 'auto' }
$env:GOOS = 'windows'; $env:CGO_ENABLED = '0'; $env:GOFIPS140 = 'off'

Push-Location -LiteralPath $src
try {
    Invoke-Checked go mod download
    foreach ($arch in @(@{ Go = 'amd64'; Folder = 'x64' }, @{ Go = '386'; Folder = 'x86' })) {
        Say "Building cloudflared for $($arch.Folder)..."
        $env:GOARCH = $arch.Go
        $out = Join-Path $work "out\$($arch.Folder)"
        # (single quotes inside -ldflags: Windows PowerShell doesn't pass on embedded double quotes)
        Invoke-Checked go build -mod=readonly -ldflags "-X 'main.Version=$ver' -X 'main.BuildTime=$date'" -o (Join-Path $out 'cloudflared.exe') ./cmd/cloudflared
        Publish-Build -From $out -Arch $arch.Folder -Version $ver -Note "Source: https://github.com/$repo, tag $tag"
    }
}
finally { Pop-Location }
Complete-Build
