# Builds PowerShell 7 from source (github.com/PowerShell/PowerShell) into Built\x64, Built\x86 and Built\ARM64, like
# its release zips (PowerShell-<version>-win-<arch>.zip): with the project's own build module, the way its release
# pipeline does (.pipelines\templates\windows-hosted-build.yml: Start-PSBuild -Runtime <rid> -Configuration Release
# -Clean -PSModuleRestore -ReleaseTag <tag>, with -UseNuGetOrg for the public NuGet feed), then the zip's clean-up
# (Update-PSSignedBuildFolder: no *.pdb, *.xml, *.zip or *.r2rmap at the top; no satellite-assembly folders), unsigned
# Needs: the exact .NET SDK global.json asks for (eg. 11.0.100; a portable copy is downloaded when this PC has none),
#        PowerShell 7 to run build.psm1 (this PC's pwsh, or a portable copy of the latest release), Git
# Usage: build.cmd [-Version <x.y.z>] [-KeepWork] [-WorkDir <folder>]
param([string]$Version, [string]$WorkDir, [switch]$KeepWork, [switch]$Yes)
. "$PSScriptRoot\..\..\_Build-App.ps1"
trap { Stop-Build $_ }

$repo = 'PowerShell/PowerShell'
$tag = if ($Version) { 'v' + ($Version -replace '^v') } else { Get-LatestGitHubTag $repo }
$work = Start-Build -Name 'PowerShell' -NeedGB 8
$src = Join-Path $work 'src'
# (some test folders' paths are long: git's core.longpaths, through git's GIT_CONFIG_* variables; Start-PSBuild
# -Clean runs git clean in it too)
$env:GIT_CONFIG_COUNT = '1'; $env:GIT_CONFIG_KEY_0 = 'core.longpaths'; $env:GIT_CONFIG_VALUE_0 = 'true'
Get-GitSource "https://github.com/$repo.git" $tag $src
Add-ToPath (Split-Path -Parent (Get-Git))

# (the exact SDK in global.json: build.psm1 won't build with another one)
$sdkVersion = (Get-Content -LiteralPath (Join-Path $src 'global.json') -Raw | ConvertFrom-Json).sdk.version
$haveSdk = $false
$systemDotnet = Get-Command dotnet.exe -ErrorAction SilentlyContinue | Select-Object -First 1
if ($systemDotnet) { $haveSdk = [bool](@(& $systemDotnet.Source --list-sdks 2>$null) -match "^$([regex]::Escape($sdkVersion)) ") }
if (-not $haveSdk) {
    $dotnetDir = Join-Path $script:toolsDir 'dotnet'
    if (-not (Test-Path -LiteralPath "$dotnetDir\dotnet.exe") -or -not (@(& "$dotnetDir\dotnet.exe" --list-sdks 2>$null) -match "^$([regex]::Escape($sdkVersion)) ")) {
        Say "Getting a portable .NET SDK ($sdkVersion)..."
        $installer = Join-Path $script:toolsDir 'dotnet-install.ps1'; Get-File 'https://dot.net/v1/dotnet-install.ps1' $installer
        & powershell -NoProfile -ExecutionPolicy Bypass -File $installer -Version $sdkVersion -InstallDir $dotnetDir -NoPath
        if ($LASTEXITCODE -ne 0) { throw "Couldn't get the .NET SDK $sdkVersion" }
    }
    Add-ToPath $dotnetDir; $env:DOTNET_ROOT = $dotnetDir; $env:DOTNET_MULTILEVEL_LOOKUP = '0'
}
$env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'; $env:DOTNET_NOLOGO = '1'

# PowerShell 7 to run build.psm1: this PC's, or a portable copy of the latest release
$pwsh = $null
$found = Get-Command pwsh.exe -ErrorAction SilentlyContinue | Select-Object -First 1
if ($found) {
    $pwshVersion = "$(& $found.Source -NoProfile -NonInteractive -Command '$PSVersionTable.PSVersion.ToString()' 2>$null)".Trim()
    if ($pwshVersion -match '^(\d+)\.(\d+)' -and [version]"$($Matches[1]).$($Matches[2])" -ge [version]'7.4') { $pwsh = $found.Source }
}
if (-not $pwsh) {
    $pwshDir = Join-Path $script:toolsDir 'pwsh'
    if (-not (Test-Path -LiteralPath "$pwshDir\pwsh.exe")) {
        $latest = Get-LatestGitHubTag $repo
        $zipName = "PowerShell-$($latest -replace '^v')-win-x64.zip"
        Say "Getting a portable PowerShell ($latest) to run the build..."
        $zip = Join-Path $script:toolsDir $zipName
        Get-File "https://github.com/$repo/releases/download/$latest/$zipName" $zip
        [IO.Compression.ZipFile]::ExtractToDirectory($zip, $pwshDir); Remove-Item -LiteralPath $zip
    }
    $pwsh = Join-Path $pwshDir 'pwsh.exe'
}
Say "Using $pwsh"

$ver = $tag -replace '^v'
foreach ($arch in @(@{ Runtime = 'win7-x64'; Folder = 'x64' }, @{ Runtime = 'win7-x86'; Folder = 'x86' }, @{ Runtime = 'win-arm64'; Folder = 'ARM64' })) {
    Say "Building PowerShell $ver for $($arch.Folder) (Start-PSBuild -Runtime $($arch.Runtime))..."
    $out = Join-Path $work "out\$($arch.Folder)"
    $command = "`$ErrorActionPreference = 'Stop'; Import-Module '$src\build.psm1' -Force; " +
        "Start-PSBuild -Runtime '$($arch.Runtime)' -Configuration Release -Output '$out' -Clean -PSModuleRestore -ReleaseTag '$tag' -UseNuGetOrg"
    # (ReadyToRun's symbol files for ARM64 need the ARM64 DiaSymReader, which doesn't load on an x64 PC, so they're turned
    # off in PowerShell.Common.props for that build; the zip leaves them out anyway)
    if ($arch.Runtime -eq 'win-arm64' -and $env:PROCESSOR_ARCHITECTURE -ne 'ARM64') {
        $props = Join-Path $src 'PowerShell.Common.props'
        [IO.File]::WriteAllText($props, [IO.File]::ReadAllText($props).Replace('<PublishReadyToRunEmitSymbols>true</PublishReadyToRunEmitSymbols>', '<PublishReadyToRunEmitSymbols>false</PublishReadyToRunEmitSymbols>'))
    }
    $saved = $env:PSModulePath; $env:PSModulePath = ''
    try { Invoke-Checked $pwsh -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command $command }
    finally { $env:PSModulePath = $saved }
    if (-not (Test-Path -LiteralPath (Join-Path $out 'pwsh.exe'))) { throw "Start-PSBuild didn't make $out\pwsh.exe (see the messages above)" }
    foreach ($filter in '*.pdb', '*.xml', '*.zip', '*.r2rmap') { Get-ChildItem -Path (Join-Path $out $filter) -File -ErrorAction SilentlyContinue | Remove-Item -Force }
    # (and, like the zip packaging (packaging.psm1), no satellite-assembly folders: the zips are en-US only)
    foreach ($dir in Get-ChildItem -LiteralPath $out -Directory) {
        $isCulture = $true; try { $null = [Globalization.CultureInfo]::GetCultureInfo($dir.Name) } catch { $isCulture = $false }
        $files = @(Get-ChildItem -LiteralPath $dir.FullName -Recurse -File)
        if ($isCulture -and $files -and -not ($files | Where-Object { $_.Name -notlike '*.resources.dll' })) { Remove-Item -LiteralPath $dir.FullName -Recurse -Force }
    }
    Publish-Build -From $out -Arch $arch.Folder -Version $ver -Note "Source: https://github.com/$repo, tag $tag (unsigned)"
}
Complete-Build
