param([string]$Version, [string]$WorkDir, [switch]$KeepWork, [switch]$Yes)
. "$PSScriptRoot\..\_Build-App.ps1"
trap { Stop-Build $_ }

# Builds rclone from source (github.com/rclone/rclone) into Built\x64, Built\x86 and Built\ARM64, the way its
# Windows releases are built (the CI's windows job: "make compile_all" = bin/cross-compile.go with the cmount tag,
# -buildmode exe, no cgo, the version resource from bin/resource_windows.go), plus the files the release zip has
# beside rclone.exe (README.txt, README.html and rclone.1 from the source; not git-log.txt)
# Needs: Go (this PC's when new enough for rclone's go.mod, otherwise a portable copy is downloaded)
# Usage: build.cmd [-Version <x.y.z>] [-KeepWork] [-WorkDir <folder>]

$repo = 'rclone/rclone'
$tag = if ($Version) { 'v' + ($Version -replace '^v') } else { Get-LatestGitHubTag $repo }
$work = Start-Build -Name 'RClone' -NeedGB 3
$src = Join-Path $work 'src'
# (some test data file names are too long for Windows' usual 260-character paths: git's core.longpaths, set here
# through the environment since Get-GitSource has no option for it)
$env:GIT_CONFIG_COUNT = '1'; $env:GIT_CONFIG_KEY_0 = 'core.longpaths'; $env:GIT_CONFIG_VALUE_0 = 'true'
Get-GitSource "https://github.com/$repo.git" $tag $src

$goLine = Select-String -LiteralPath (Join-Path $src 'go.mod') -Pattern '^go (\d+\.\d+)' | Select-Object -First 1
Use-Tool go -Version $(if ($goLine) { $goLine.Matches[0].Groups[1].Value })
$env:GOTOOLCHAIN = 'auto'

Push-Location -LiteralPath $src
try {
    Invoke-Checked go mod download
    # (cross-compile.go cleans the build folder with rm / mkdir, which Windows doesn't have, so it's made here)
    New-Item -ItemType Directory -Path (Join-Path $src 'build') -Force | Out-Null
    Say 'Building rclone for Windows (x64, x86, ARM64)...'
    Invoke-Checked go run bin/cross-compile.go -compile-only -no-clean -include '^windows/' -tags cmount -buildmode exe -parallel 1 -build-p 4 $tag
    foreach ($arch in @(@{ Go = 'amd64'; Folder = 'x64' }, @{ Go = '386'; Folder = 'x86' }, @{ Go = 'arm64'; Folder = 'ARM64' })) {
        $dir = Get-ChildItem -LiteralPath (Join-Path $src 'build') -Directory | Where-Object { $_.Name -like "*-windows-$($arch.Go)" } | Select-Object -First 1
        if (-not $dir -or -not (Test-Path -LiteralPath (Join-Path $dir.FullName 'rclone.exe'))) { throw "The build didn't make rclone.exe for $($arch.Go)" }
        # (what cross-compile.go's buildZip adds)
        Copy-Item -LiteralPath (Join-Path $src 'MANUAL.txt') -Destination (Join-Path $dir.FullName 'README.txt')
        Copy-Item -LiteralPath (Join-Path $src 'MANUAL.html') -Destination (Join-Path $dir.FullName 'README.html')
        Copy-Item -LiteralPath (Join-Path $src 'rclone.1') -Destination $dir.FullName
        Publish-Build -From $dir.FullName -Arch $arch.Folder -Version ($tag -replace '^v') -Note "Source: https://github.com/$repo, tag $tag"
    }
}
finally { Pop-Location }
Complete-Build
