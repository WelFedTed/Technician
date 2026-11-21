# Builds Eraser from source (the Subversion repository at https://svn.code.sf.net/p/eraser/code, trunk/eraser, at the
# revision of the newest release in winget's manifests: its version is 6.2.0.<revision>) into Built\x86 and Built\x64, the
# way Eraser.msbuild's Build target does (Eraser.sln, Release, x86 and x64): Eraser.exe and its libraries, plugins
# and shell extension (the official download is the installer made from these by Installer\*.wixproj, with WiX 3)
# (The projects' UpdateVersions.bat needs TortoiseSVN's SubWCRev to fill in the revision; it's replaced with one that
# does the same with PowerShell. The C++ projects ask for Visual Studio 2019's v142 tools; they're built with VS 2022's)
# Needs: Visual Studio 2022 with the C++ x86/x64 tools, C++/CLI support, ATL and MFC, the C# compiler and the .NET
#        Framework 4.8 targeting pack and SDK; Subversion (a portable MSYS2 with its subversion package is set up in
#        the build's tools folder)
# Usage: build.cmd [-Version <6.2.0.revision>] [-KeepWork] [-WorkDir <folder>]
param([string]$Version, [string]$WorkDir, [switch]$KeepWork, [switch]$Yes)
. "$PSScriptRoot\..\_Build-App.ps1"
trap { Stop-Build $_ }

$svnUrl = 'https://svn.code.sf.net/p/eraser/code/trunk/eraser'
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
$src = Join-Path $work 'src'

# (the source: an export of trunk at that revision, with MSYS2's svn)
Use-Msys2 -Packages 'subversion'
Say "Getting the source (r$revision) from $svnUrl..."
# (run in the work folder, so the command has no Windows path in it: Windows PowerShell mangles double quotes inside
# arguments to programs)
Invoke-Msys2 -Env msys -Dir $work -Command "svn export -q --non-interactive -r $revision '$svnUrl' src"

# (UpdateVersions.bat <working copy> <template> <output>: SubWCRev's job, filling in $WCREV$ and the dates)
$updater = Join-Path $work 'UpdateVersions.ps1'
[IO.File]::WriteAllText($updater, @"
param([string]`$Template, [string]`$Output)
`$now = Get-Date -Format 'yyyy/MM/dd HH:mm:ss'
`$text = [IO.File]::ReadAllText(`$Template).Replace('`$WCREV`$', '$revision').Replace('`$WCDATE`$', `$now).Replace('`$WCNOW`$', `$now).Replace('`$WCRANGE`$', '$revision').Replace('`$WCURL`$', '$svnUrl')
[IO.File]::WriteAllText(`$Output, `$text)
"@)
[IO.File]::WriteAllText((Join-Path $src 'UpdateVersions.bat'), "@echo off`r`npowershell -NoProfile -ExecutionPolicy Bypass -File `"$updater`" -Template `"%~2`" -Output `"%~3`"`r`nexit /b %errorlevel%`r`n")

Use-VisualStudio -Arch x64 -Version '[17.0,18.0)' -Components 'Microsoft.VisualStudio.Component.VC.Tools.x86.x64', 'Microsoft.VisualStudio.Component.VC.CLI.Support', 'Microsoft.VisualStudio.Component.VC.ATL', 'Microsoft.VisualStudio.Component.VC.ATLMFC', 'Microsoft.VisualStudio.Component.Roslyn.Compiler', 'Microsoft.Net.Component.4.8.TargetingPack', 'Microsoft.Net.Component.4.8.SDK' | Out-Null

$sln = Join-Path $src 'Eraser.sln'
foreach ($arch in @(@{ Platform = 'x86'; Folder = 'x86' }, @{ Platform = 'x64'; Folder = 'x64' })) {
    Say "Building Eraser for $($arch.Folder)..."
    Invoke-Checked msbuild $sln /restore /t:Rebuild /p:Configuration=Release "/p:Platform=$($arch.Platform)" /p:PlatformToolset=v143 /m:4 /nologo /verbosity:minimal
    $exe = Get-ChildItem -LiteralPath $src -Recurse -Filter 'Eraser.exe' | Where-Object { $_.DirectoryName -match '\\bin\\' -and $_.DirectoryName -match 'Release' -and ($arch.Platform -eq 'x86' -or $_.DirectoryName -match 'x64') } | Sort-Object LastWriteTime | Select-Object -Last 1
    if (-not $exe) { throw "The build didn't make Eraser.exe for $($arch.Folder)" }
    Publish-Build -From $exe.DirectoryName -Arch $arch.Folder -Version $Version -Note "Source: $svnUrl r$revision"
}
Complete-Build
