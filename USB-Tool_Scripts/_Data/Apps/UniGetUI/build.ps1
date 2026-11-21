# Builds UniGetUI from source (github.com/Devolutions/UniGetUI) the way its release workflow makes the portable zips
# (.github\workflows\build-release.yml: scripts\set-version.ps1, then a NativeAOT dotnet publish of UniGetUI.Avalonia,
# its IntegrityTree.json and the ForceUniGetUIPortable marker file) into Built\x64, and into Built\ARM64 when Visual
# Studio has the ARM64 C++ tools (NativeAOT links with Visual Studio's linker)
# (The GitHub sign-in / backup feature's OAuth client id is a GitHub secret, so it's missing from this build unless
# you set UNIGETUI_GITHUB_CLIENT_ID / UNIGETUI_GITHUB_CLIENT_SECRET first)
# Needs: the .NET SDK global.json asks for (this PC's, or a portable copy), Visual Studio 2022 with the C++ x86/x64
#        tools (and the ARM64 ones, Microsoft.VisualStudio.Component.VC.Tools.ARM64, for the ARM64 build)
# Usage: build.cmd [-Version <x.y.z>] [-KeepWork] [-WorkDir <folder>]
param([string]$Version, [string]$WorkDir, [switch]$KeepWork, [switch]$Yes)
. "$PSScriptRoot\..\_Build-App.ps1"
trap { Stop-Build $_ }

$repo = 'Devolutions/UniGetUI'
$tag = if ($Version) { 'v' + ($Version -replace '^v') } else { Get-LatestGitHubTag $repo }
$ver = $tag -replace '^v'
$work = Start-Build -Name 'UniGetUI' -NeedGB 8
$src = Join-Path $work 'src'
# (some of its paths are long: git's core.longpaths, through git's GIT_CONFIG_* variables)
$env:GIT_CONFIG_COUNT = '1'; $env:GIT_CONFIG_KEY_0 = 'core.longpaths'; $env:GIT_CONFIG_VALUE_0 = 'true'
Get-GitSource "https://github.com/$repo.git" $tag $src
Add-NuGetOrg $work

$sdkLine = [regex]::Match([IO.File]::ReadAllText((Join-Path $src 'global.json')), '"version"\s*:\s*"(\d+\.\d+)')
Use-Tool dotnet -Version $(if ($sdkLine.Success) { $sdkLine.Groups[1].Value } else { '10.0' })
$env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'; $env:DOTNET_NOLOGO = '1'
# (NativeAOT finds Visual Studio's linker with its findvcvarsall.bat, which runs vswhere.exe from the PATH: without it
# there, cmd's "not recognized" message ends up in the linker's path)
Add-ToPath (Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer')
Use-VisualStudio -Arch x64 -Version '[17.0,18.0)' | Out-Null

# (scripts\set-version.ps1, which needs PowerShell 7, done here: the version and the next build number)
$utf8Bom = New-Object Text.UTF8Encoding($true)
$fourPart = (@(($ver -split '-')[0] -split '\.') + @('0', '0', '0', '0'))[0..3] -join '.'
$buildNumber = [int]([IO.File]::ReadAllText((Join-Path $src 'scripts\BuildNumber')).Trim()) + 1
$coreData = Join-Path $src 'src\UniGetUI.Core.Data\CoreData.cs'
$text = [IO.File]::ReadAllText($coreData)
$text = [regex]::Replace($text, '(?m)^(\s*)public const string VersionName =.*$', "`${1}public const string VersionName = `"$ver`"; // Do not modify this line, use file scripts/set-version.ps1")
$text = [regex]::Replace($text, '(?m)^(\s*)public const int BuildNumber =.*$', "`${1}public const int BuildNumber = $buildNumber; // Do not modify this line, use file scripts/set-version.ps1")
[IO.File]::WriteAllText($coreData, $text, $utf8Bom)
$asmInfo = Join-Path $src 'src\SharedAssemblyInfo.cs'
$text = [IO.File]::ReadAllText($asmInfo)
$text = $text -replace 'AssemblyVersion\("[^"]*"\)', "AssemblyVersion(`"$fourPart`")" -replace 'AssemblyFileVersion\("[^"]*"\)', "AssemblyFileVersion(`"$fourPart`")" -replace 'AssemblyInformationalVersion\("[^"]*"\)', "AssemblyInformationalVersion(`"$ver`")"
[IO.File]::WriteAllText($asmInfo, $text, $utf8Bom)
$manifest = Join-Path $src 'src\UniGetUI.Avalonia\app.manifest'
if (Test-Path -LiteralPath $manifest) {
    $text = [IO.File]::ReadAllText($manifest)
    $text = [regex]::Replace($text, '(?s)(<assemblyIdentity\b.*?\bversion\s*=\s*")[^"]*(")', "`${1}$fourPart`${2}")
    [IO.File]::WriteAllText($manifest, $text, $utf8Bom)
}

Say 'Restoring the packages...'
Invoke-Checked dotnet restore (Join-Path $src 'src\UniGetUI.Windows.slnx')

$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
$hasArm64 = [bool](& $vswhere -products * -version '[17.0,18.0)' -requires Microsoft.VisualStudio.Component.VC.Tools.ARM64 -property installationPath)
$project = Join-Path $src 'src\UniGetUI.Avalonia\UniGetUI.Avalonia.csproj'
foreach ($arch in @(@{ Platform = 'x64'; Folder = 'x64' }, @{ Platform = 'arm64'; Folder = 'ARM64' })) {
    if ($arch.Platform -eq 'arm64' -and -not $hasArm64) {
        Say 'Skipping the ARM64 build: NativeAOT needs Visual Studio 2022 with the ARM64 C++ tools (Microsoft.VisualStudio.Component.VC.Tools.ARM64)'
        continue
    }
    Say "Publishing UniGetUI for $($arch.Folder) (NativeAOT)..."
    Invoke-Checked dotnet publish $project /nologo /p:Configuration=Release "/p:Platform=$($arch.Platform)" "/p:RuntimeIdentifier=win-$($arch.Platform)" `
        "/p:PublishProfile=Win-$($arch.Platform)-NativeAot" /p:UseSharedCompilation=false /p:BuildInParallel=false /m:1 -v m
    $publishDir = Get-ChildItem -LiteralPath (Join-Path $src "src\UniGetUI.Avalonia\bin\$($arch.Platform)\Release") -Recurse -Directory -Filter 'publish' |
        Where-Object { $_.Parent.Name -eq "win-$($arch.Platform)" } | Select-Object -First 1
    if (-not $publishDir -or -not (Test-Path -LiteralPath (Join-Path $publishDir.FullName 'UniGetUI.exe'))) { throw "The publish didn't make UniGetUI.exe for win-$($arch.Platform)" }
    $out = Join-Path $work "unigetui_bin-$($arch.Platform)"
    Copy-Item -LiteralPath $publishDir.FullName -Destination $out -Recurse
    # (the workflow drops PDBs over 1 MB, writes IntegrityTree.json (the SHA256 of every file, which UniGetUI checks
    # when it starts), then adds the ForceUniGetUIPortable file to the zip)
    Get-ChildItem -LiteralPath $out -Recurse -File -Filter '*.pdb' | Where-Object { $_.Length -gt 1MB } | Remove-Item -Force
    $hashes = @{}
    Get-ChildItem -LiteralPath $out -Recurse -File | ForEach-Object {
        $rel = $_.FullName.Substring($out.Length).TrimStart('\', '/') -replace '\\', '/'
        if ($rel -ne 'IntegrityTree.json') { $hashes[$rel] = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLower() }
    }
    $sorted = [ordered]@{}
    foreach ($key in ($hashes.Keys | Sort-Object)) { $sorted[$key] = $hashes[$key] }
    [IO.File]::WriteAllText((Join-Path $out 'IntegrityTree.json'), ($sorted | ConvertTo-Json -Depth 1), (New-Object Text.UTF8Encoding($false)))
    Copy-Item -LiteralPath (Join-Path $src 'InstallerExtras\ForceUniGetUIPortable') -Destination $out
    Publish-Build -From $out -Arch $arch.Folder -Version $ver -Note "Source: https://github.com/$repo, tag $tag (portable, NativeAOT)"
}
Complete-Build
