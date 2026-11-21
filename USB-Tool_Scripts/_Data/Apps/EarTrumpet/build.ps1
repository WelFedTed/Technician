# Builds EarTrumpet from source (github.com/File-New-Project/EarTrumpet, its master branch, which
# install.eartrumpet.app/master is built from) into Built\x86: the loose EarTrumpet.exe and its files, as its CI
# workflow builds them for the Chocolatey package (.github\workflows\main.yml, "Build EarTrumpet")
# (The official download, which update.cmd gets, is the signed MSIX bundle from EarTrumpet.Package.wapproj; making
# that needs Visual Studio's UWP / Desktop Bridge packaging tools, so this build makes the plain program instead.
# Its version x.y.z.N is GitVersion's: the last version tag x.y.z.0 plus N commits on master, so the build is of the
# Nth commit after that tag, with N from install.eartrumpet.app's current version, like update.cmd. The project's
# GitVersionTask doesn't load in a current MSBuild, so it's turned off and the version is set here instead)
# Needs: MSBuild with the C# compiler (Visual Studio or its Build Tools), the Windows 10/11 SDK (Windows.winmd),
#        Git; NuGet (nuget.exe) and the .NET Framework 4.6.2 reference assemblies are downloaded into the work folder
# Usage: build.cmd [-Version <x.y.z.N, or master for the newest commit>] [-KeepWork] [-WorkDir <folder>]
param([string]$Version, [string]$WorkDir, [switch]$KeepWork, [switch]$Yes)
. "$PSScriptRoot\..\_Build-App.ps1"
trap { Stop-Build $_ }

$repo = 'File-New-Project/EarTrumpet'
if (-not $Version) {
    $m = [regex]::Match((Get-Text 'https://install.eartrumpet.app/master/EarTrumpet.Package.appinstaller'), 'EarTrumpet\.Package_([\d.]+)_x86\.appxbundle')
    if (-not $m.Success) { throw "Couldn't find the current version on install.eartrumpet.app" }
    $Version = $m.Groups[1].Value
}
$work = Start-Build -Name 'EarTrumpet' -NeedGB 1
$src = Join-Path $work 'src'
# (the master branch with its history and tags)
$git = Get-Git
Say "Getting the source (master, with its history) from https://github.com/$repo.git..."
Invoke-Checked $git -c advice.detachedHead=false clone --single-branch --branch master "https://github.com/$repo.git" $src
Push-Location -LiteralPath $src
try {
    $baseTag = "$(& $git describe --tags --abbrev=0)".Trim()
    $commits = @(& $git rev-list --reverse --first-parent "$baseTag..HEAD")
    if ($Version -eq 'master') { $count = $commits.Count }
    else {
        if ($Version -notmatch '^(\d+\.\d+\.\d+)\.(\d+)$') { throw "-Version should look like 2.3.0.20 (or be master)" }
        $count = [int]$Matches[2]
        if (-not ($baseTag -like "$($Matches[1]).*")) { throw "Version $Version isn't from the last version tag ($baseTag) on master" }
        if ($count -gt $commits.Count) { throw "Master has only $($commits.Count) commits since $baseTag" }
        if ($count -gt 0) { Invoke-Checked $git -c advice.detachedHead=false checkout -q $commits[$count - 1] }
        else { Invoke-Checked $git -c advice.detachedHead=false checkout -q $baseTag }
    }
}
finally { Pop-Location }
$mmp = ($baseTag -split '\.')[0..2] -join '.'
$ver = "$mmp.$count"
Say "Building EarTrumpet $ver ($count commits after $baseTag)"
# MSBuild with the C# compiler (this old-style project builds with MSBuild.exe, not dotnet build)
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
$vs = if (Test-Path -LiteralPath $vswhere) { & $vswhere -latest -products * -requires Microsoft.Component.MSBuild Microsoft.VisualStudio.Component.Roslyn.Compiler -property installationPath | Select-Object -First 1 }
if (-not $vs) { Fail 'This build needs Visual Studio or its Build Tools with MSBuild and the C# compiler (Microsoft.Component.MSBuild, Microsoft.VisualStudio.Component.Roslyn.Compiler)' }
$msbuild = Join-Path $vs 'MSBuild\Current\Bin\amd64\MSBuild.exe'
Say "Using $msbuild"

# NuGet packages (packages.config, like the CI's "nuget restore"), and the .NET Framework 4.6.2 reference assemblies
# from their NuGet package (instead of the .NET Framework 4.6.2 Developer Pack)
$nuget = Join-Path $work 'tools\nuget.exe'
Get-File 'https://dist.nuget.org/win-x86-commandline/latest/nuget.exe' $nuget
$nugetConfig = Join-Path $work 'NuGet.Config'
[IO.File]::WriteAllText($nugetConfig, "<?xml version=`"1.0`" encoding=`"utf-8`"?>`r`n<configuration>`r`n  <packageSources>`r`n    <clear />`r`n    <add key=`"nuget.org`" value=`"https://api.nuget.org/v3/index.json`" protocolVersion=`"3`" />`r`n  </packageSources>`r`n</configuration>`r`n")
Say 'Restoring the NuGet packages...'
Invoke-Checked $nuget restore (Join-Path $src 'EarTrumpet\packages.config') -PackagesDirectory (Join-Path $src 'packages') -ConfigFile $nugetConfig -NonInteractive
Invoke-Checked $nuget install Microsoft.NETFramework.ReferenceAssemblies.net462 -OutputDirectory (Join-Path $work 'refasm') -ExcludeVersion -ConfigFile $nugetConfig -NonInteractive
# (moved to a short path: the WPF markup compiler loads them, and fails on paths over 260 characters)
$refRoot = Join-Path $work 'fx'
Move-Item -LiteralPath (Join-Path $work 'refasm\Microsoft.NETFramework.ReferenceAssemblies.net462\build') -Destination $refRoot

# (the project looks for Windows.winmd in the 10.0.16299.0 Windows SDK; this points it at the newest one installed)
$winmd = Get-ChildItem -Path "${env:ProgramFiles(x86)}\Windows Kits\10\UnionMetadata\*\Windows.winmd" -ErrorAction SilentlyContinue | Sort-Object { [version]$_.Directory.Name } -ErrorAction SilentlyContinue | Select-Object -Last 1
if (-not $winmd) { Fail 'This build needs the Windows 10/11 SDK (Windows.winmd in Windows Kits\10\UnionMetadata)' }
$project = Join-Path $src 'EarTrumpet\EarTrumpet.csproj'
$text = [IO.File]::ReadAllText($project)
[IO.File]::WriteAllText($project, $text.Replace('UnionMetadata\10.0.16299.0\Windows.winmd', "UnionMetadata\$($winmd.Directory.Name)\Windows.winmd"))

# (the version attributes GitVersionTask would have added)
$attributes = @("[assembly: System.Reflection.AssemblyVersion(`"$mmp.0`")]", "[assembly: System.Reflection.AssemblyFileVersion(`"$ver`")]", "[assembly: System.Reflection.AssemblyInformationalVersion(`"$ver`")]")
[IO.File]::AppendAllText((Join-Path $src 'EarTrumpet\Properties\AssemblyInfo.cs'), "`r`n" + ($attributes -join "`r`n") + "`r`n")

# (the translations' satellite assemblies: an old-style project makes them with al.exe from the .NET Framework SDK;
# this adds a target that makes them with the C# compiler instead, like SDK-style projects do)
$satTargets = Join-Path $work 'CscSatelliteAssemblies.targets'
[IO.File]::WriteAllText($satTargets, @"
<Project>
  <PropertyGroup>
    <CreateSatelliteAssembliesDependsOn>`$(CreateSatelliteAssembliesDependsOn);_CscSatelliteAssemblies</CreateSatelliteAssembliesDependsOn>
  </PropertyGroup>
  <Target Name="_CscSatelliteAssemblies" DependsOnTargets="ResolveAssemblyReferences"
          Inputs="`$(MSBuildAllProjects);@(_SatelliteAssemblyResourceInputs);`$(IntermediateOutputPath)`$(TargetName)`$(TargetExt)"
          Outputs="`$(IntermediateOutputPath)%(Culture)\`$(TargetName).resources.dll"
          Condition="'@(_SatelliteAssemblyResourceInputs)' != '' and '`$(GenerateSatelliteAssembliesForCore)' == 'true'">
    <MakeDir Directories="@(_SatelliteAssemblyResourceInputs->'`$(IntermediateOutputPath)%(Culture)')" />
    <PropertyGroup>
      <_SatInfoFile>`$(IntermediateOutputPath)%(_SatelliteAssemblyResourceInputs.Culture)\`$(TargetName).resources.cs</_SatInfoFile>
      <_SatOutput>`$(IntermediateOutputPath)%(_SatelliteAssemblyResourceInputs.Culture)\`$(TargetName).resources.dll</_SatOutput>
    </PropertyGroup>
    <ItemGroup>
      <_SatAttribute Remove="@(_SatAttribute)" />
      <_SatAttribute Include="System.Reflection.AssemblyCultureAttribute"><_Parameter1>%(_SatelliteAssemblyResourceInputs.Culture)</_Parameter1></_SatAttribute>
      <_SatAttribute Include="System.Reflection.AssemblyVersionAttribute"><_Parameter1>$mmp.0</_Parameter1></_SatAttribute>
      <_SatReferences Remove="@(_SatReferences)" />
      <_SatReferences Include="@(ReferencePath)" Condition="'%(Filename)' == 'mscorlib'" />
    </ItemGroup>
    <WriteCodeFragment AssemblyAttributes="@(_SatAttribute)" Language="C#" OutputFile="`$(_SatInfoFile)" />
    <Csc Resources="@(_SatelliteAssemblyResourceInputs)" Sources="`$(_SatInfoFile)" OutputAssembly="`$(_SatOutput)" References="@(_SatReferences)"
         NoConfig="true" NoLogo="true" NoStandardLib="true" Optimize="true" Deterministic="true" TargetType="Library"
         ToolExe="`$(CscToolExe)" ToolPath="`$(CscToolPath)" UseSharedCompilation="false" />
  </Target>
</Project>
"@)

Say 'Building EarTrumpet...'
$out = Join-Path $work 'loose'
Invoke-Checked $msbuild $project /p:Platform=x86 /p:Configuration=Release /p:Channel=Chocolatey /p:DisableGitVersionTask=true `
    "/p:GitVersion_MajorMinorPatch=$mmp" "/p:GitVersion_CommitsSinceVersionSource=$count" "/p:OutputPath=$out\\" "/p:TargetFrameworkRootPath=$refRoot\\" `
    /p:GenerateSatelliteAssembliesForCore=true "/p:CustomAfterMicrosoftCommonTargets=$satTargets" /m:4 /nologo /verbosity:minimal

$exe = Join-Path $out 'EarTrumpet.exe'
if (-not (Test-Path -LiteralPath $exe)) { throw "The build didn't make $exe" }
Publish-Build -From $out -Arch 'x86' -Version $ver -Note "Source: https://github.com/$repo, master $($commits[[Math]::Max(0, $count - 1)]) ($count commits after $baseTag; the loose program, not the MSIX package)"
Complete-Build
