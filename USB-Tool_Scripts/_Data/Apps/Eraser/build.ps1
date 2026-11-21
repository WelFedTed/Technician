# Builds Eraser from source (the Subversion repository at https://svn.code.sf.net/p/eraser/code, trunk/eraser, at the
# revision of the newest release in winget's manifests: its version is 6.2.0.<revision>) into Built\x86 and Built\x64, the
# way Eraser.msbuild's Build target does (Eraser.sln, Release, x86 and x64): Eraser.exe and its libraries, plugins
# and shell extension (x64 only: the solution's x86 build has none) (the official download is the installer made from these by Installer\*.wixproj, with WiX 3)
# (The projects' UpdateVersions.bat needs TortoiseSVN's SubWCRev to fill in the revision; it's replaced with one that
# does the same with PowerShell. The C++ projects ask for Visual Studio 2019's v142 tools; they're built with VS 2022's.
# The BevelLine control comes from the repository's vendor folder, and the .NET Framework 4.0 / 4.6 / 4.7.2 / 4.8
# reference assemblies from their NuGet packages. The installer and its bootstrapper aren't built.)
# Needs: Visual Studio 2022 with the C++ x86/x64 tools, C++/CLI support, ATL and MFC, the C# compiler and the .NET
#        Framework 4.8 targeting pack and SDK; Subversion (a portable MSYS2 with its subversion package is set up in
#        the build's tools folder)
# Usage: build.cmd [-Version <6.2.0.revision>] [-KeepWork] [-WorkDir <folder>]
param([string]$Version, [string]$WorkDir, [switch]$KeepWork, [switch]$Yes)
. "$PSScriptRoot\..\_Build-App.ps1"
trap { Stop-Build $_ }

$svnUrl = 'https://svn.code.sf.net/p/eraser/code/trunk/eraser'
$vendorUrl = 'https://svn.code.sf.net/p/eraser/code/vendor/trunk/BevelLine'
if (-not $Version) {
    # (the newest version in winget's manifests, which update.cmd's winget download uses too: eg. 6.2.2996 for 6.2.0.2996)
    $names = @(Get-Text 'https://api.github.com/repos/microsoft/winget-pkgs/contents/manifests/e/Eraser/Eraser' | ConvertFrom-Json | ForEach-Object { $_.name } | Where-Object { $_ -match '^\d+\.\d+\.\d+$' })
    if (-not $names) { throw "Couldn't find Eraser's versions in winget's manifests" }
    $latest = $names | Sort-Object { [version]$_ } | Select-Object -Last 1
    $parts = $latest -split '\.'
    $Version = "$($parts[0]).$($parts[1]).0.$($parts[2])"
}
if ($Version -notmatch '^\d+\.\d+\.\d+\.(\d+)$') { throw "-Version should look like 6.2.0.2996 (its last part is the Subversion revision)" }
$revision = $Matches[1]
$work = Start-Build -Name 'Eraser' -NeedGB 2
# (the solution refers to ..\..\..\EraserExtras for its BevelLine control, so the source goes two folders deeper than
# the work folder, and the control (from the repository's vendor folder) into EraserExtras there)
$src = Join-Path $work 'e\trunk\eraser'

# (the source: an export of trunk at that revision, with MSYS2's svn)
Use-Msys2 -Packages 'subversion'
Say "Getting the source (r$revision) from $svnUrl..."
# (run in the work folder, so the command has no Windows path in it: Windows PowerShell mangles double quotes inside
# arguments to programs)
Invoke-Msys2 -Env msys -Dir $work -Command "mkdir -p e/trunk && svn export -q --non-interactive -r $revision '$svnUrl' e/trunk/eraser"
Invoke-Msys2 -Env msys -Dir $work -Command "mkdir -p EraserExtras && svn export -q --non-interactive -r $revision '$vendorUrl' EraserExtras/BevelLine_Code_2005_BETA2"

# (UpdateVersions.bat <working copy> <template> <output>: SubWCRev's job, filling in $WCREV$, the dates and the
# $WCMODS?a:b$ style choices: an export has no local changes, isn't mixed, and is from Subversion)
$updater = Join-Path $work 'UpdateVersions.ps1'
[IO.File]::WriteAllText($updater, @'
param([string]$Template, [string]$Output, [string]$Revision, [string]$Url)
$now = Get-Date -Format 'yyyy/MM/dd HH:mm:ss'
$text = [IO.File]::ReadAllText($Template).Replace('$WCREV$', $Revision).Replace('$WCDATE$', $now).Replace('$WCNOW$', $now).Replace('$WCRANGE$', $Revision).Replace('$WCURL$', $Url)
$text = [regex]::Replace($text, '\$WCINSVN\?([^:$]*):([^$]*)\$', '$1')
$text = [regex]::Replace($text, '\$WC[A-Z]+\?([^:$]*):([^$]*)\$', '$2')
[IO.File]::WriteAllText($Output, $text)
'@)
[IO.File]::WriteAllText((Join-Path $src 'UpdateVersions.bat'), "@echo off`r`npowershell -NoProfile -ExecutionPolicy Bypass -File `"$updater`" -Template `"%~2`" -Output `"%~3`" -Revision $revision -Url `"$svnUrl`"`r`nexit /b %errorlevel%`r`n")

Use-VisualStudio -Arch x64 -Version '[17.0,18.0)' -Components 'Microsoft.VisualStudio.Component.VC.Tools.x86.x64', 'Microsoft.VisualStudio.Component.VC.CLI.Support', 'Microsoft.VisualStudio.Component.VC.ATL', 'Microsoft.VisualStudio.Component.VC.ATLMFC', 'Microsoft.VisualStudio.Component.Roslyn.Compiler', 'Microsoft.Net.Component.4.8.TargetingPack', 'Microsoft.Net.Component.4.8.SDK' | Out-Null

# (the projects target .NET Framework 4.0 to 4.8, and Visual Studio only has the newest targeting packs: the
# reference assemblies for each version come from Microsoft's Microsoft.NETFramework.ReferenceAssemblies.net4x NuGet
# packages, in one folder that's used as the targeting packs' root)
$refRoot = Join-Path $work 'refasm'
$frameworks = Get-ChildItem -LiteralPath $work -Recurse -File | Where-Object { $_.Extension -in '.csproj', '.vcxproj' } |
    Select-String -Pattern '<TargetFrameworkVersion>v(\d)\.(\d)(?:\.(\d))?<' | ForEach-Object { 'net' + $_.Matches[0].Groups[1].Value + $_.Matches[0].Groups[2].Value + $_.Matches[0].Groups[3].Value }
# (and 4.8's, for the C++/CLI project, which names no version)
$frameworks = @($frameworks) + 'net48' | Sort-Object -Unique
foreach ($fw in $frameworks) {
    Say "Getting the .NET Framework reference assemblies ($fw)..."
    $pkg = Join-Path $work "refasm-$fw.nupkg"
    Get-File "https://www.nuget.org/api/v2/package/Microsoft.NETFramework.ReferenceAssemblies.$fw/1.0.3" $pkg
    $unpacked = Join-Path $work "refasm-$fw"
    [IO.Compression.ZipFile]::ExtractToDirectory($pkg, $unpacked)
    New-Item -ItemType Directory -Path $refRoot -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $unpacked 'build\.NETFramework') -Destination $refRoot -Recurse -Force
}
Add-NuGetOrg $work
# (the assemblies are strong-named with the project's private "Strong Name.snk", which isn't in the repository: a new
# key is made for this build, the same one for all of them, since Eraser only loads plugins signed like itself)
$rsa = New-Object Security.Cryptography.RSACryptoServiceProvider(1024)
$snk = $rsa.ExportCspBlob($true)
# (as a signature key, CALG_RSA_SIGN, like "sn -k" makes: the exported blob says CALG_RSA_KEYX, which al.exe refuses)
$snk[5] = 0x24
foreach ($dir in @($src, (Join-Path $work 'EraserExtras\BevelLine_Code_2005_BETA2\BevelLine'))) { [IO.File]::WriteAllBytes((Join-Path $dir 'Strong Name.snk'), $snk) }

$sln = Join-Path $src 'Eraser.sln'
# (Eraser.msbuild's Build target builds the whole solution, which has the installer and its bootstrapper too: they need
# WiX 3, Boost and LZMA, so only the program's projects are built: Eraser and what it uses, the plugins and the shell
# extension; the solution's Release|x86 has no shell extension, only Release|x64 does)
$targets = 'Eraser:Rebuild;Eraser_DefaultPlugins:Rebuild;Eraser_BlackBox:Rebuild'
# (Eraser.csproj's post-build step runs InsertIcons.exe, the developer's own tool that isn't in the repository, to add
# the task list file icon to Eraser.exe: it's left out, so .ersx files show Eraser's own icon)
foreach ($arch in @(@{ Platform = 'x86'; Folder = 'x86'; Targets = $targets }, @{ Platform = 'x64'; Folder = 'x64'; Targets = "$targets;Eraser_Shell:Rebuild" })) {
    Say "Building Eraser for $($arch.Folder)..."
    Invoke-Checked msbuild $sln /restore "/t:$($arch.Targets)" "/p:TargetFrameworkRootPath=$refRoot\\" /p:PostBuildEvent= /p:Configuration=Release "/p:Platform=$($arch.Platform)" /p:PlatformToolset=v143 /m:4 /nologo /verbosity:minimal
    # (both platforms build into bin\Release: the .NET programs (AnyCPU), with the native parts in Win32\ and x64\; the
    # result has the platform's native DLLs beside the programs, as the installer puts them, and no debug symbols)
    $bin = Join-Path $src 'bin\Release'
    if (-not (Test-Path -LiteralPath (Join-Path $bin 'Eraser.exe'))) { throw "The build didn't make Eraser.exe for $($arch.Folder)" }
    $native = Join-Path $bin $(if ($arch.Platform -eq 'x86') { 'Win32' } else { 'x64' })
    $out = Join-Path $work "out\$($arch.Folder)"
    New-Item -ItemType Directory -Path $out -Force | Out-Null
    Get-ChildItem -LiteralPath $bin | Where-Object { $_.Name -notin 'Win32', 'x64' } | Copy-Item -Destination $out -Recurse -Force
    Copy-Item -Path (Join-Path $native '*') -Destination $out -Force
    Get-ChildItem -LiteralPath $out -Recurse -File | Where-Object { $_.Extension -eq '.pdb' } | Remove-Item -Force
    Publish-Build -From $out -Arch $arch.Folder -Version $Version -Note "Source: $svnUrl r$revision (signed with a key made for this build; no InsertIcons step)"
}
Complete-Build
