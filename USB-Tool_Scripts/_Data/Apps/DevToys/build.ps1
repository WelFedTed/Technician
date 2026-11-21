# Builds DevToys from source (github.com/DevToys-app/DevToys) the way its NUKE pipeline (src\build\Build.cs, target
# PublishApp) makes the portable downloads: the DevToys app (WPF + Blazor, self-contained, unpackaged) into
# Built\x64, Built\x86 and Built\ARM64, and the DevToys command line (single-file DevToys.CLI.exe) into Built\<arch>\CLI,
# each with the built-in tools plugin in Plugins\DevToys.Tools, as the release has it: that's a separate project
# (github.com/DevToys-app/DevToys.Tools, no tags), built here from its last commit before the DevToys release's
# commit and packed like its NuGet package (DevToys.Tools <x.y.z>-preview), then unpacked there
# (init.ps1's restore steps first: the npm packages of DevToys.Blazor and the Monaco editor from the npm registry)
# Needs: the .NET 8 SDK (this PC's, or a portable copy; global.json asks for 8.0), Node.js with npm (this PC's, or
#        a portable copy)
# Usage: build.cmd [-Version <x.y.z.w>] [-KeepWork] [-WorkDir <folder>]
param([string]$Version, [string]$WorkDir, [switch]$KeepWork, [switch]$Yes)
. "$PSScriptRoot\..\_Build-App.ps1"
trap { Stop-Build $_ }
# (DevToys 2's releases are all marked as pre-releases)
$repo = 'DevToys-app/DevToys'
$tag = if ($Version) { 'v' + ($Version -replace '^v') } else { Get-LatestGitHubTag $repo -Pre }
$ver = $tag -replace '^v'
$work = Start-Build -Name 'DevToys' -NeedGB 6
$src = Join-Path $work 'src'
# (some of the plugin's paths are long: git's core.longpaths, through git's GIT_CONFIG_* variables)
$env:GIT_CONFIG_COUNT = '1'; $env:GIT_CONFIG_KEY_0 = 'core.longpaths'; $env:GIT_CONFIG_VALUE_0 = 'true'
Get-GitSource "https://github.com/$repo.git" $tag $src
Add-NuGetOrg $work

Use-Tool dotnet -Version '8.0'
Use-Tool node
$env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'; $env:DOTNET_NOLOGO = '1'

# (init.ps1: the NuGet and npm packages, then the Monaco editor)
Say 'Restoring the packages (NuGet and npm)...'
Invoke-Checked dotnet restore /p:RestoreNpm=true /p:PublishReadyToRun=true /v:quiet (Join-Path $src 'src\DevToys-Windows.sln')
Say 'Getting the Monaco editor...'
# (without the progress bar, which makes Windows PowerShell's Invoke-WebRequest in that script very slow)
$monaco = Join-Path $src 'tools\Restore-MonacoEditor.ps1'
Invoke-Checked powershell -NoProfile -ExecutionPolicy Bypass -Command "`$ProgressPreference = 'SilentlyContinue'; & '$monaco' -RootFolder '$src'; exit `$LASTEXITCODE"

# (the pipeline's SetVersion step, with the release's version)
foreach ($file in Get-ChildItem -LiteralPath (Join-Path $src 'src') -Recurse -Filter '*AssemblyVersion.cs') {
    $text = [IO.File]::ReadAllText($file.FullName)
    $text = $text -replace 'AssemblyVersion\("[^"]*"\)', "AssemblyVersion(`"$ver`")" -replace 'AssemblyFileVersion\("[^"]*"\)', "AssemblyFileVersion(`"$ver`")" -replace 'AssemblyInformationalVersion\("[^"]*"\)', "AssemblyInformationalVersion(`"$ver`")"
    [IO.File]::WriteAllText($file.FullName, $text)
}

# (the pipeline's CompileGenerators step: the source generators the app's projects use)
foreach ($generator in Get-ChildItem -LiteralPath (Join-Path $src 'src') -Recurse -Filter '*.csproj' | Where-Object { $_.FullName -match '\\generators\\' }) {
    Say "Building the $($generator.BaseName) generator..."
    Invoke-Checked dotnet build $generator.FullName --configuration Release /p:PublishTrimmed=false /m:4
}

# The DevToys.Tools plugin: its last commit at the time of the DevToys tag's commit, packed as <x.y.z>-preview
$git = Get-Git
Push-Location -LiteralPath $src
try { $tagDate = "$(& $git log -1 --format=%cI)".Trim() } finally { Pop-Location }
$toolsSrc = Join-Path $work 'tools-src'
Say 'Getting the DevToys.Tools plugin source from https://github.com/DevToys-app/DevToys.Tools.git...'
Invoke-Checked $git clone -q --single-branch --branch main 'https://github.com/DevToys-app/DevToys.Tools.git' $toolsSrc
Push-Location -LiteralPath $toolsSrc
try {
    $toolsCommit = "$(& $git rev-list -1 "--before=$tagDate" main)".Trim()
    if (-not $toolsCommit) { throw "DevToys.Tools has no commit from before $tagDate" }
    Invoke-Checked $git -c advice.detachedHead=false checkout -q $toolsCommit
}
finally { Pop-Location }
$pluginVersion = (($ver -split '\.')[0..2] -join '.') + '-preview'
Say "Packing DevToys.Tools $pluginVersion (commit $($toolsCommit.Substring(0, 7)))..."
Invoke-Checked dotnet pack (Join-Path $toolsSrc 'src\DevToys.Tools\DevToys.Tools.csproj') --configuration Release "/p:Version=$pluginVersion" /m:4
$nupkg = Get-ChildItem -LiteralPath (Join-Path $toolsSrc 'bin') -Recurse -Filter "DevToys.Tools.$pluginVersion.nupkg" | Select-Object -First 1
if (-not $nupkg) { throw "Packing DevToys.Tools made no DevToys.Tools.$pluginVersion.nupkg" }
$pluginDir = Join-Path $work 'plugin\DevToys.Tools'
[IO.Compression.ZipFile]::ExtractToDirectory($nupkg.FullName, $pluginDir)
Remove-Item -LiteralPath (Join-Path $pluginDir '_rels') -Recurse -Force -ErrorAction SilentlyContinue
$app = Join-Path $src 'src\app\dev\platforms\desktop\DevToys.Windows\DevToys.Windows.csproj'
$cli = Join-Path $src 'src\app\dev\platforms\desktop\DevToys.CLI\DevToys.CLI.csproj'
foreach ($arch in @(@{ Rid = 'win-x64'; Platform = 'x64'; Folder = 'x64' }, @{ Rid = 'win-x86'; Platform = 'x86'; Folder = 'x86' }, @{ Rid = 'win-arm64'; Platform = 'arm64'; Folder = 'ARM64' })) {
    Say "Publishing DevToys for $($arch.Folder)..."
    $appOut = Join-Path $work "publish\app-$($arch.Rid)"
    Invoke-Checked dotnet publish $app --configuration Release --runtime $arch.Rid "/p:Platform=$($arch.Platform)" --self-contained true /p:PublishSingleFile=false `
        /p:PublishReadyToRun=false /p:PublishTrimmed=false "/p:RuntimeIdentifierOverride=$($arch.Rid)" /p:Unpackaged=true /m:4 --output $appOut
    Say "Publishing the DevToys command line for $($arch.Folder)..."
    $cliOut = Join-Path $work "publish\cli-$($arch.Rid)"
    Invoke-Checked dotnet publish $cli --configuration Release --runtime $arch.Rid --self-contained true /p:PublishSingleFile=true `
        /p:PublishReadyToRun=false /p:PublishTrimmed=false /m:4 --output $cliOut
    foreach ($dir in $appOut, $cliOut) {
        New-Item -ItemType Directory -Path (Join-Path $dir 'Plugins') -Force | Out-Null
        Copy-Item -LiteralPath $pluginDir -Destination (Join-Path $dir 'Plugins') -Recurse -Force
        Copy-Item -LiteralPath (Join-Path $src 'LICENSE.md') -Destination $dir
    }
    Publish-Build -From $appOut -Arch $arch.Folder -Version $ver -Note "Source: https://github.com/$repo, tag $tag (portable app); plugin DevToys.Tools $pluginVersion from https://github.com/DevToys-app/DevToys.Tools commit $toolsCommit"
    Publish-Build -From $cliOut -Arch "$($arch.Folder)\CLI" -Version $ver -Note "Source: https://github.com/$repo, tag $tag (portable command line); plugin DevToys.Tools $pluginVersion from https://github.com/DevToys-app/DevToys.Tools commit $toolsCommit"
}
Complete-Build