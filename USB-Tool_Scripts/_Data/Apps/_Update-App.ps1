# Update-App - shared updater for the apps in _Data\Apps
# --------------------------------------------------
# Each app's update.cmd calls this with the app's download details, once for each kind of download the app
# has, each kept in its own folder in the app folder (-AppDir):
#   Installer  installers (the app's install.cmd starts them)
#   Portable   apps that run without installing (run.cmd)
#   CLI        command-line tools (cli.cmd opens a command prompt with them on the PATH)
# Each of these holds its own build folders (x86, x64, ...), version file, checksums and parity data.
# It downloads the latest version, checks the download is real (not an error page or empty file)
# before touching the old version, then rewrites the .version file, checksums.sfv and parity data.
# The version file is named v<version>_<build date>.version, where the build date comes from the
# GitHub release, the files inside the archive, the server's Last-Modified date or the exe itself.
#
# Where to get the app (pick one):
#   -Url <url>                        a fixed download link
#   -Page <url> -Link <regex>         scrape the link from a web page; the highest version number wins
#       [-UrlFormat <fmt>]            build the link from the regex's first group, eg. "https://x/app_{0}.zip"
#       [-PageIndex <url> -PageIndexLink <regex>]   when each release has its own page (eg. Blender's
#                                     release/Blender5.3/), the highest first group of the regex on the
#                                     index page fills {0} in -Page (and -Page86 / -PageArm)
#   -GitHub <owner/repo> -Asset <regex>   an asset of the latest GitHub release
#   -Manual [-Page <url>] [-Note <text>]  can't be downloaded automatically; prints where to get it
# Optional 32-bit and ARM64 downloads (the same options with 86 or Arm on the end):
#   -Url86 / -Link86 / -Asset86 from the same source,
#   or -UrlFormat86 to build it from the same version -Link captured,
#   or -Page86 -Link86 [-UrlFormat86] when the build is listed on its own page
#   (and -UrlArm / -LinkArm / -AssetArm / -UrlFormatArm / -PageArm for ARM64)
# Extra files saved next to the main one, named as in their links: -Extra "url1,url2"
#   or more assets from the same GitHub release: -ExtraAsset <regex>
#
# What to do with it:
#   -SaveAs, -SaveAs86, -SaveAsArm    save a single file under this name (default: name from the link)
#   -Extract                          unzip it (.zip or .7z)
#   -Paf                              a PortableApps.com installer (.paf.exe): unpack the ready-to-run app
#                                     straight into the build folder (eg. x86_x64\7-ZipPortable.exe + App\)
#                                     and delete the installer; the app's Data folder (its settings) is
#                                     kept when updating
#   -Into, -Into86, -IntoArm          the build folder for each download:
#                                     x64   = only runs on 64-bit Windows
#                                     x86   = runs on 32-bit Windows (also installers and scripts)
#                                     ARM64 = ARM64 Windows build
#                                     x86_x64 / x86_x64_ARM64 = one download holding several builds that
#                                     share files (eg. CPU-Z's cpuz_x32.exe + cpuz_x64.exe + cpuz.ini)
#                                     Anything else at the top of the app folder, and any build folder the
#                                     app no longer uses, is moved into the -Into folder
#   -Flatten                          if the archive has one top folder, use what's inside it
#   -Clean                            delete the old version's files first (keeps update.cmd, *.url, run.cmd and -Keep)
#   -Keep "a,b"                       extra file/folder names to keep when cleaning
#   -MoveFrom <folder>                where this download used to be kept on the USB (the app folder itself, from
#                                     before the Installer / Portable / CLI folders, or an old folder of its own
#                                     such as "7-Zip Portable"); what's there is moved into -AppDir first, and
#                                     an old folder of its own is then removed
#   -DataFolder <name>                create this folder next to the app in each build folder and keep it when
#                                     cleaning; apps such as VS Code (data) and Sublime Text (Data) only run in
#                                     portable mode, with their settings on the USB, when it exists
#   -Referer <url>                    some sites only allow downloads from their own pages
#   -Password <text>                  password for a protected .zip (extracted with 7-Zip's 7za.exe)
#   -UserAgent <text>                 send this instead of a browser user agent (eg. "curl" for SourceForge)
#   -Inner, -Inner86, -InnerArm       take this folder from inside the archive instead of all of it
#   -VersionFrom <file>               read the version from this file instead of the link
#   -VersionFromUrl                   read the version from the download link before the exe (for installers
#                                     whose exe carries the installer's version, eg. Firefox)
#
# Exit codes: 0 = updated or already up to date, 1 = failed, 2 = needs a manual update,
#             3 = updated, but Windows Defender blocked some files

param(
    [Parameter(Mandatory = $true)][string]$Name,
    [string]$AppDir = (Get-Location).Path,
    [string]$Url, [string]$Url86, [string]$UrlArm, [string]$Extra,
    [string]$Page, [string]$Link, [string]$Link86, [string]$LinkArm,
    [string]$UrlFormat, [string]$UrlFormat86, [string]$UrlFormatArm, [string]$Page86, [string]$PageArm,
    [string]$GitHub, [string]$Asset, [string]$Asset86, [string]$AssetArm,
    [switch]$Manual, [string]$Note,
    [string]$SaveAs, [string]$SaveAs86, [string]$SaveAsArm,
    [switch]$Extract, [switch]$Paf, [string]$Into, [string]$Into86, [string]$IntoArm,
    [switch]$Flatten, [switch]$Clean, [string]$Keep, [string]$DataFolder,
    [string]$Referer, [string]$Password, [string]$UserAgent, [string]$ExtraAsset,
    [string]$Inner, [string]$Inner86, [string]$InnerArm,
    [string]$VersionFrom, [switch]$VersionFromUrl,
    [string]$MoveFrom,
    [switch]$CheckOnly,
    [string]$PageIndex, [string]$PageIndexLink
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$userAgent = if ($UserAgent) { $UserAgent } else { 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36' }
$curl = Join-Path $env:SystemRoot 'System32\curl.exe'
$toolsDir = Join-Path $env:LOCALAPPDATA 'USB-Tool\tools'
# the type folder (Installer, Portable or CLI) may not exist yet on the USB
New-Item -ItemType Directory -Path $AppDir -Force | Out-Null
$AppDir = (Resolve-Path -LiteralPath $AppDir).Path
$alwaysKeep = @('update.cmd', '*.url', 'run.cmd', 'install.cmd', 'cli.cmd', '*.version', 'checksums.sfv', '*.par2')
# each app folder holds up to three of these, each with its own build folders, version file and checksums
$typeFolders = @('Installer', 'Portable', 'CLI')

# .NET is used for hashing and unzipping instead of Get-FileHash / Expand-Archive,
# because those cmdlets go missing when PowerShell's module path is broken (eg. launched from PowerShell 7)
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Say([string]$message) { Write-Host $message }

function Get-Sha256([string]$path) {
    $sha = [Security.Cryptography.SHA256]::Create()
    $stream = [IO.File]::OpenRead($path)
    try { return ([BitConverter]::ToString($sha.ComputeHash($stream)) -replace '-', '') }
    finally { $stream.Close(); $sha.Dispose() }
}

# ---------------------------------------------------------------------------------------------
# Finding the download link
# ---------------------------------------------------------------------------------------------

function Get-Text([string]$address) {
    $text = & $curl -sSL --fail --retry 2 --connect-timeout 20 -A $userAgent $address | Out-String
    if ($LASTEXITCODE -ne 0) { throw "Couldn't load $address (curl exit code $LASTEXITCODE)" }
    return $text
}

# compare version numbers found in a string, eg. "cpu-z_3.02-en.zip" > "cpu-z_2.17-en.zip"
function Get-VersionKey([string]$text) {
    $parts = [regex]::Matches($text, '\d+') | ForEach-Object { [long]$_.Value }
    return , @($parts)
}

function Select-Highest([string[]]$candidates) {
    $best = $null; $bestKey = $null
    foreach ($candidate in $candidates) {
        $key = Get-VersionKey $candidate
        if ($null -eq $best) { $best = $candidate; $bestKey = $key; continue }
        for ($i = 0; $i -lt [Math]::Max($key.Count, $bestKey.Count); $i++) {
            $a = if ($i -lt $key.Count) { $key[$i] } else { -1 }
            $b = if ($i -lt $bestKey.Count) { $bestKey[$i] } else { -1 }
            if ($a -gt $b) { $best = $candidate; $bestKey = $key; break }
            if ($a -lt $b) { break }
        }
    }
    return $best
}

$script:pageVersion = $null
function Find-PageLink([string]$pattern, [string]$pageUrl = $Page, [string]$format = $UrlFormat) {
    $html = Get-Text $pageUrl
    $found = [regex]::Matches($html, $pattern, 'IgnoreCase') | ForEach-Object {
        if ($format) { $format -f $_.Groups[1].Value } else { $_.Value }
    } | Select-Object -Unique
    if (-not $found) { throw "No link matching '$pattern' on $pageUrl (the page may have changed)" }
    $best = Select-Highest @($found)
    # remember the version the main link's regex captured, for -UrlFormat86
    if ($format -and $pageUrl -eq $Page -and $format -eq $UrlFormat) {
        $script:pageVersion = [regex]::Matches($html, $pattern, 'IgnoreCase') |
            Where-Object { ($format -f $_.Groups[1].Value) -eq $best } |
            Select-Object -First 1 | ForEach-Object { $_.Groups[1].Value }
    }
    return ([Uri]::new([Uri]$pageUrl, $best)).AbsoluteUri
}

$script:release = $null
function Find-GitHubAsset([string]$pattern) {
    if (-not $script:release) {
        $script:release = Get-Text "https://api.github.com/repos/$GitHub/releases/latest" | ConvertFrom-Json
    }
    $match = $script:release.assets | Where-Object { $_.name -match $pattern } | Select-Object -First 1
    if (-not $match) { throw "No asset matching '$pattern' in the latest $GitHub release ($($script:release.tag_name))" }
    return $match.browser_download_url
}

# the link for a 32-bit or ARM64 build: its own page, the same page/release as the main build,
# or the main link's version dropped into a format string
function Resolve-AltLink([string]$direct, [string]$pageLink, [string]$asset, [string]$altPage, [string]$format) {
    if ($altPage -and $pageLink) { return Find-PageLink $pageLink $altPage $format }
    $found = Resolve-Link $direct $pageLink $asset
    if (-not $found -and $format -and $script:pageVersion) { $found = $format -f $script:pageVersion }
    return $found
}

function Resolve-Link([string]$direct, [string]$pageLink, [string]$asset) {
    if ($direct) { return $direct }
    if ($Page -and $pageLink) { return Find-PageLink $pageLink }
    if ($GitHub -and $asset) { return Find-GitHubAsset $asset }
    return $null
}

# ---------------------------------------------------------------------------------------------
# Downloading and checking
# ---------------------------------------------------------------------------------------------

function Get-Download([string]$address, [string]$outFile) {
    # -R keeps the server's Last-Modified date on the file, used for the build date
    $curlArgs = @('-L', '-R', '--fail', '--retry', '2', '--connect-timeout', '20', '--progress-bar', '-A', $userAgent, '-o', $outFile, '-w', '%{url_effective}')
    if ($Referer) { $curlArgs += @('-e', $Referer) }
    $finalUrl = & $curl @curlArgs $address
    if ($LASTEXITCODE -ne 0) { throw "Download failed (curl exit code $LASTEXITCODE): $address" }
    return [Uri]::UnescapeDataString(($finalUrl | Select-Object -Last 1).Split('?')[0])
}

# file name for a download without -SaveAs: GitHub redirects to a link ending in a random ID,
# so prefer the name in the original link, then the redirected link's, and make sure it has an extension
function Get-DownloadName([string]$link, [string]$finalUrl, [string]$kind) {
    $fromLink = [Uri]::UnescapeDataString((Split-Path -Leaf ($link.Split('?')[0])))
    $fromFinal = Split-Path -Leaf $finalUrl
    # extensions can be long, eg. .msixbundle
    $name = if ($fromLink -match '\.[A-Za-z0-9]{2,12}$') { $fromLink } else { $fromFinal }
    if ($name -notmatch '\.[A-Za-z0-9]{2,12}$' -and $kind -in @('exe', 'msi', 'zip', '7z')) { $name += ".$kind" }
    foreach ($bad in [IO.Path]::GetInvalidFileNameChars()) { $name = $name.Replace([string]$bad, '_') }
    return $name
}

# the server's ETag / Last-Modified / size for a link, from a header-only request ('' if the server won't say)
function Get-RemoteStamp([string]$address) {
    $curlArgs = @('-sIL', '--fail', '--connect-timeout', '20', '-A', $userAgent, '-o', 'NUL', '-w', '%header{etag}|%header{last-modified}|%header{content-length}')
    if ($Referer) { $curlArgs += @('-e', $Referer) }
    $out = & $curl @curlArgs $address 2>$null
    if ($LASTEXITCODE -ne 0) { return '' }
    $stamp = ($out | Out-String).Trim()
    if (($stamp -replace '\|', '').Trim()) { return $stamp }
    return ''
}

function Get-FileKind([string]$path) {
    $bytes = [byte[]]::new(8)
    $stream = [IO.File]::OpenRead($path)
    try { [void]$stream.Read($bytes, 0, 8) } finally { $stream.Close() }
    if ($bytes[0] -eq 0x4D -and $bytes[1] -eq 0x5A) { return 'exe' }
    if ($bytes[0] -eq 0x50 -and $bytes[1] -eq 0x4B) { return 'zip' }
    if ($bytes[0] -eq 0x37 -and $bytes[1] -eq 0x7A -and $bytes[2] -eq 0xBC) { return '7z' }
    if ($bytes[0] -eq 0xD0 -and $bytes[1] -eq 0xCF -and $bytes[2] -eq 0x11) { return 'msi' }
    $start = [Text.Encoding]::ASCII.GetString($bytes).TrimStart()
    # an error or landing page, not a script that happens to start with < (eg. a PowerShell <# comment)
    if ($start -match '^<(!|html|head|body)') { return 'html' }
    return 'other'
}

function Test-Download([string]$path, [string]$address, [switch]$AllowPlain) {
    $size = (Get-Item -LiteralPath $path).Length
    if ($size -lt 10KB) { throw "Download is only $size bytes, probably an error page: $address" }
    $kind = Get-FileKind $path
    if ($kind -eq 'html') { throw "Download is a web page, not the app (the link may have changed): $address" }
    # (-Extra files may be plain files next to the unzipped app, eg. 7zr.exe next to 7-Zip Extra)
    if ($Extract -and -not $AllowPlain -and $kind -notin @('zip', '7z')) { throw "Expected a .zip or .7z but got a $kind file: $address" }
    return $kind
}

# ---------------------------------------------------------------------------------------------
# Applying the update
# ---------------------------------------------------------------------------------------------

function Get-Tool([string]$exeName, [string]$address, [switch]$Zipped) {
    $exe = Join-Path $toolsDir $exeName
    if (Test-Path -LiteralPath $exe) { return $exe }
    New-Item -ItemType Directory -Path $toolsDir -Force | Out-Null
    Say "Downloading $exeName (one-off, cached in $toolsDir)..."
    if ($Zipped) {
        $zip = Join-Path $toolsDir "$exeName.zip"
        & $curl -sSL --fail -A $userAgent -o $zip $address
        if ($LASTEXITCODE -ne 0) { throw "Couldn't download $exeName" }
        $unzipped = Join-Path $toolsDir ([Guid]::NewGuid().ToString('N'))
        [IO.Compression.ZipFile]::ExtractToDirectory($zip, $unzipped)
        $found = Get-ChildItem -LiteralPath $unzipped -Recurse -Filter $exeName | Select-Object -First 1
        if (-not $found) { throw "$exeName wasn't in the download" }
        Move-Item -LiteralPath $found.FullName -Destination $exe -Force
        Remove-Item -LiteralPath $zip, $unzipped -Recurse -Force
    }
    else {
        & $curl -sSL --fail -A $userAgent -o $exe $address
        if ($LASTEXITCODE -ne 0) { throw "Couldn't download $exeName" }
    }
    return $exe
}

function Clear-OldVersion([string]$folder, [string[]]$alsoKeep) {
    if (-not (Test-Path -LiteralPath $folder)) { return }
    $keepList = $alwaysKeep + @(($Keep -split '[,;]') | ForEach-Object { $_.Trim() } | Where-Object { $_ }) + @($alsoKeep | Where-Object { $_ }) + @($DataFolder | Where-Object { $_ })
    Get-ChildItem -LiteralPath $folder -Force | Where-Object {
        $item = $_
        -not ($keepList | Where-Object { $item.Name -like $_ })
    } | Remove-Item -Recurse -Force
}

# -DataFolder: make the folder that puts the app in portable mode, in each build folder that has the app
# (also on installs that are already up to date, so existing copies on the USB get it too)
function Add-DataFolder([object[]]$jobs) {
    if (-not $DataFolder) { return }
    foreach ($job in $jobs) {
        $folder = if ($job.Into) { Join-Path $AppDir $job.Into } else { $AppDir }
        if (-not (Test-Path -LiteralPath $folder)) { continue }
        $data = Join-Path $folder $DataFolder
        if (Test-Path -LiteralPath $data) { continue }
        New-Item -ItemType Directory -Path $data | Out-Null
        Say "Created $(if ($job.Into) { "$($job.Into)\" })$DataFolder (portable mode: settings are kept on the USB)"
    }
}

# 7-Zip's full command-line tool (handles password-protected zips); comes in "7-Zip Extra", which is a .7z,
# so 7zr.exe unpacks it once and 7za.exe is cached with the other tools
# full 7-Zip (7z.exe + 7z.dll), which can unpack NSIS installers such as PortableApps .paf.exe files;
# the 7-Zip installer is itself a 7z archive, so 7zr.exe unpacks it once and it's cached with the other tools
function Get-SevenZipFull {
    $folder = Join-Path $toolsDir '7z'
    $exe = Join-Path $folder '7z.exe'
    if ((Test-Path -LiteralPath $exe) -and (Test-Path -LiteralPath (Join-Path $folder '7z.dll'))) { return $exe }
    $sevenZip = Get-Tool '7zr.exe' 'https://www.7-zip.org/a/7zr.exe'
    Say "Downloading 7-Zip (one-off, cached in $folder)..."
    $release = Get-Text 'https://api.github.com/repos/ip7z/7zip/releases/latest' | ConvertFrom-Json
    # the 32-bit build runs everywhere
    $installer = $release.assets | Where-Object { $_.name -match '^7z\d+\.exe$' } | Select-Object -First 1
    if (-not $installer) { throw "Couldn't find the 7-Zip installer in the latest 7-Zip release" }
    $download = Join-Path $toolsDir '7z-installer.exe'
    & $curl -sSL --fail -A $userAgent -o $download $installer.browser_download_url
    if ($LASTEXITCODE -ne 0) { throw "Couldn't download 7-Zip" }
    if (Test-Path -LiteralPath $folder) { Remove-Item -LiteralPath $folder -Recurse -Force }
    & $sevenZip x $download "-o$folder" -y | Out-Null
    Remove-Item -LiteralPath $download -Force
    if (-not (Test-Path -LiteralPath $exe)) { throw "Couldn't unpack 7-Zip" }
    return $exe
}

# unpacks a PortableApps .paf.exe into $staging (the ready-to-run app: launcher, App\, Other\) and returns
# the app's version from its appinfo.ini
function Expand-Paf([string]$installer, [string]$staging) {
    $sevenZip = Get-SevenZipFull
    New-Item -ItemType Directory -Path $staging | Out-Null
    & $sevenZip x $installer "-o$staging" -y | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Couldn't unpack the PortableApps installer (7z exit code $LASTEXITCODE)" }
    # the installer's own files, not part of the app
    Get-ChildItem -LiteralPath $staging -Force | Where-Object { $_.Name -like '$*' -or $_.Name -like '`[NSIS`]*' } | Remove-Item -Recurse -Force
    if (-not (Get-ChildItem -LiteralPath $staging -Filter '*.exe' -File | Select-Object -First 1)) {
        throw 'No launcher (.exe) at the top of the PortableApps installer'
    }
    $appInfo = Join-Path $staging 'App\AppInfo\appinfo.ini'
    if (Test-Path -LiteralPath $appInfo) {
        $text = [IO.File]::ReadAllText($appInfo)
        foreach ($key in 'DisplayVersion', 'PackageVersion') {
            $m = [regex]::Match($text, "(?im)^\s*$key\s*=\s*(.+?)\s*$")
            if ($m.Success) { return $m.Groups[1].Value }
        }
    }
    return $null
}

function Get-SevenZipA {
    $exe = Join-Path $toolsDir '7za.exe'
    if (Test-Path -LiteralPath $exe) { return $exe }
    $sevenZip = Get-Tool '7zr.exe' 'https://www.7-zip.org/a/7zr.exe'
    Say "Downloading 7za.exe (one-off, cached in $toolsDir)..."
    $release = Get-Text 'https://api.github.com/repos/ip7z/7zip/releases/latest' | ConvertFrom-Json
    $extra = $release.assets | Where-Object { $_.name -match '^7z\d+-extra\.7z$' } | Select-Object -First 1
    if (-not $extra) { throw "Couldn't find 7-Zip Extra in the latest 7-Zip release" }
    $archive = Join-Path $toolsDir '7z-extra.7z'
    $unpacked = Join-Path $toolsDir ([Guid]::NewGuid().ToString('N'))
    & $curl -sSL --fail -A $userAgent -o $archive $extra.browser_download_url
    if ($LASTEXITCODE -ne 0) { throw "Couldn't download 7-Zip Extra" }
    & $sevenZip x $archive "-o$unpacked" -y | Out-Null
    # the 32-bit 7za.exe at the top of the archive runs everywhere
    Move-Item -LiteralPath (Join-Path $unpacked '7za.exe') -Destination $exe -Force
    Remove-Item -LiteralPath $archive, $unpacked -Recurse -Force
    return $exe
}

# copies a folder tree; files Windows Defender blocks are skipped and listed (eg. NirSoft password tools),
# so one flagged tool doesn't stop a whole package like NirLauncher from updating
$script:blocked = @()
function Copy-AllowedFiles([string]$source, [string]$destination) {
    New-Item -ItemType Directory -Path $destination -Force | Out-Null
    foreach ($item in Get-ChildItem -LiteralPath $source -Force) {
        $target = Join-Path $destination $item.Name
        if ($item.PSIsContainer) { Copy-AllowedFiles $item.FullName $target; continue }
        try { Copy-Item -LiteralPath $item.FullName -Destination $target -Force }
        catch {
            if ($_.Exception.Message -notmatch 'virus or potentially unwanted software') { throw }
            $script:blocked += $item.Name
        }
    }
}

# extracts to a temp folder and returns the folder holding the app's files
function Expand-ToStaging([string]$archive, [string]$kind, [string]$staging, [string]$inner) {
    New-Item -ItemType Directory -Path $staging | Out-Null
    if ($Password) {
        $sevenZipA = Get-SevenZipA
        & $sevenZipA x $archive "-p$Password" "-o$staging" -y | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "Couldn't extract the password-protected download (7za exit code $LASTEXITCODE)" }
    }
    elseif ($kind -eq '7z') {
        $sevenZip = Get-Tool '7zr.exe' 'https://www.7-zip.org/a/7zr.exe'
        & $sevenZip x $archive "-o$staging" -y | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "Couldn't extract the download (7zr exit code $LASTEXITCODE)" }
    }
    else {
        [IO.Compression.ZipFile]::ExtractToDirectory($archive, $staging)
    }
    $top =@(Get-ChildItem -LiteralPath $staging -Force)
    if ($top.Count -eq 0) { throw 'The downloaded archive is empty' }
    if ($inner) {
        # take one folder from inside the archive, eg. "AnyBurn(64-bit)"
        $innerPath = Join-Path $staging $inner
        if (-not (Test-Path -LiteralPath $innerPath)) { throw "No '$inner' folder in the download (the archive layout may have changed)" }
        return $innerPath
    }
    if ($Flatten -and $top.Count -eq 1 -and $top[0].PSIsContainer) { return $top[0].FullName }
    return $staging
}

# ---------------------------------------------------------------------------------------------
# Version file, checksums and parity
# ---------------------------------------------------------------------------------------------

Add-Type -TypeDefinition @'
public static class UsbToolCrc32 {
    static readonly uint[] Table = MakeTable();
    static uint[] MakeTable() {
        var t = new uint[256];
        for (uint i = 0; i < 256; i++) {
            uint c = i;
            for (int k = 0; k < 8; k++) c = (c & 1) != 0 ? 0xEDB88320u ^ (c >> 1) : c >> 1;
            t[i] = c;
        }
        return t;
    }
    public static string OfFile(string path) {
        uint crc = 0xFFFFFFFFu;
        var buffer = new byte[1 << 20];
        using (var s = System.IO.File.OpenRead(path)) {
            int n;
            while ((n = s.Read(buffer, 0, buffer.Length)) > 0)
                for (int i = 0; i < n; i++) crc = Table[(crc ^ buffer[i]) & 0xFF] ^ (crc >> 8);
        }
        return (crc ^ 0xFFFFFFFFu).ToString("x8");
    }
}
'@

# ProductVersion from an .msi installer's property table
function Get-MsiVersion([string]$path) {
    try {
        $installer = New-Object -ComObject WindowsInstaller.Installer
        $db = $installer.GetType().InvokeMember('OpenDatabase', 'InvokeMethod', $null, $installer, @($path, 0))
        $view = $db.GetType().InvokeMember('OpenView', 'InvokeMethod', $null, $db, @("SELECT Value FROM Property WHERE Property = 'ProductVersion'"))
        [void]$view.GetType().InvokeMember('Execute', 'InvokeMethod', $null, $view, $null)
        $row = $view.GetType().InvokeMember('Fetch', 'InvokeMethod', $null, $view, $null)
        $value = if ($row) { $row.GetType().InvokeMember('StringData', 'GetProperty', $null, $row, 1) } else { $null }
        [void]$view.GetType().InvokeMember('Close', 'InvokeMethod', $null, $view, $null)
        [void][Runtime.InteropServices.Marshal]::ReleaseComObject($view)
        [void][Runtime.InteropServices.Marshal]::ReleaseComObject($db)
        return $value
    }
    catch { return $null }
}

function Get-Version([object[]]$jobs) {
    if ($VersionFrom) {
        $file = Join-Path $AppDir $VersionFrom
        if (Test-Path -LiteralPath $file) {
            $v = (Get-Item -LiteralPath $file).VersionInfo.FileVersionRaw
            if ($v -and $v.ToString() -ne '0.0.0.0') { return $v.ToString() }
        }
    }
    if ($script:release) { return ($script:release.tag_name -replace '^v', '') }
    # PortableApps apps say their version in appinfo.ini (the installer itself is deleted)
    if ($Paf -and $jobs[0].PafVersion) { return $jobs[0].PafVersion }
    # some installers carry their own (installer) version, not the app's, so read the link instead
    if ($VersionFromUrl) {
        $m = [regex]::Match((Split-Path -Leaf $jobs[0].FinalUrl), '\d+(?:[._]\d+)+')
        if ($m.Success) { return ($m.Value -replace '_', '.') }
    }
    foreach ($job in $jobs) {
        if (-not $Extract -and $job.Target -like '*.msi') {
            $v = Get-MsiVersion $job.Target
            if ($v) { return $v }
        }
        if (-not $Extract -and $job.Target -like '*.exe') {
            $v = (Get-Item -LiteralPath $job.Target).VersionInfo.FileVersionRaw
            if ($v -and $v.ToString() -ne '0.0.0.0') { return $v.ToString() }
        }
    }
    $leaf = Split-Path -Leaf $jobs[0].FinalUrl
    $m = [regex]::Match($leaf, '\d+(?:[._]\d+)+')
    if ($m.Success) { return ($m.Value -replace '_', '.') }
    $m = [regex]::Match($leaf, '\d{3,}')
    if ($m.Success) { return $m.Value }
    foreach ($exe in Get-ChildItem -LiteralPath $AppDir -Recurse -Filter '*.exe' -File) {
        $v = $exe.VersionInfo.FileVersionRaw
        if ($v -and $v.ToString() -ne '0.0.0.0') { return $v.ToString() }
    }
    return 'unknown'
}

# the date the build was made, read from the exe's PE header (link time)
function Get-PeDate([string]$path) {
    try {
        $stream = [IO.File]::OpenRead($path)
        try {
            $reader = [IO.BinaryReader]::new($stream)
            if ($reader.ReadUInt16() -ne 0x5A4D) { return $null }
            $stream.Position = 0x3C
            $stream.Position = $reader.ReadInt32() + 8
            $seconds = $reader.ReadUInt32()
        }
        finally { $stream.Close() }
        $date = [DateTimeOffset]::FromUnixTimeSeconds($seconds).LocalDateTime
        # some compilers write a hash here instead of a time, so only trust sensible dates
        if ($date -gt [datetime]'2000-01-01' -and $date -lt (Get-Date).AddDays(1)) { return $date }
    }
    catch { }
    return $null
}

# the downloaded version's build/release date, falling back to today if nothing better is known
function Get-BuildDate([object[]]$jobs) {
    # 1. GitHub release date
    if ($script:release -and $script:release.published_at) {
        return ([datetime]$script:release.published_at).ToLocalTime()
    }
    $job = $jobs[0]
    # 2. archives: the newest file inside (zip/7z entries keep their build timestamps)
    if ($Extract -and $job.Source) {
        $newest = Get-ChildItem -LiteralPath $job.Source -Recurse -File -Force |
            Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(1) } |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($newest) { return $newest.LastWriteTime }
    }
    # 3. single files: the server's Last-Modified date
    if ($job.ServerDate) { return $job.ServerDate }
    # 4. the exe's own build timestamp
    if (-not $Extract -and $job.Target -and (Test-Path -LiteralPath $job.Target)) {
        $peDate = Get-PeDate $job.Target
        if ($peDate) { return $peDate }
    }
    Say 'WARNING: no build date found for this download, so the version file uses today''s date.'
    return Get-Date
}

function Write-Checksums {
    $sfv = Join-Path $AppDir 'checksums.sfv'
    $files = Get-ChildItem -LiteralPath $AppDir -Recurse -File -Force |
        Where-Object { $_.Name -ne 'checksums.sfv' -and $_.Extension -ne '.par2' } |
        Sort-Object FullName
    $rows = foreach ($f in $files) {
        try { $crc = [UsbToolCrc32]::OfFile($f.FullName) }
        catch {
            # Defender can block reading a file even after it was copied; leave it out of the checksums
            if ($_.Exception.Message -notmatch 'virus or potentially unwanted software') { throw }
            if ($script:blocked -notcontains $f.Name) { $script:blocked += $f.Name }
            continue
        }
        [pscustomobject]@{ Path = $f.FullName.Substring($AppDir.Length).TrimStart('\'); Crc = $crc }
    }
    $width = ($rows | ForEach-Object { $_.Path.Length } | Measure-Object -Maximum).Maximum
    $lines = $rows | ForEach-Object { $_.Path.PadRight($width + 1) + $_.Crc }
    [IO.File]::WriteAllLines($sfv, [string[]]$lines)
}

function Write-Parity {
    Get-ChildItem -LiteralPath $AppDir -Filter '*.par2' -File | Remove-Item -Force
    $par2 = Get-Tool 'par2.exe' 'https://github.com/Parchive/par2cmdline/releases/download/v1.0.0/par2cmdline-1.0.0-win-x64.zip' -Zipped
    Push-Location -LiteralPath $AppDir
    try {
        & $par2 c -q -b5000 -r5 -n1 -R parity.par2 * | Out-Null
        if ($LASTEXITCODE -ne 0) { Say "WARNING: par2 couldn't create parity data (exit code $LASTEXITCODE)" }
    }
    finally { Pop-Location }
}

# build folder names; an app uses one or more of these
$archFolders = @('x86', 'x64', 'ARM64', 'x86_x64', 'x86_x64_ARM64')

# moves everything at the top of the app folder (except update.cmd, *.url, run.cmd and version/checksum/parity
# files) into $target, and merges build folders the app no longer uses (not in $used) into it too;
# where $target already has the same item, the old copy is dropped
function Move-RootFiles([string]$target, [string[]]$used) {
    $used = @($used | Where-Object { $_ })
    $items = @(Get-ChildItem -LiteralPath $AppDir -Force | Where-Object {
        $item = $_
        if ($item.PSIsContainer -and $used -contains $item.Name) { return $false }
        -not ($alwaysKeep | Where-Object { $item.Name -like $_ })
    })
    if ($items.Count -eq 0) { return $false }
    Say "Moving $($items.Count) item(s) into this app's $(Split-Path -Leaf $target) folder..."
    New-Item -ItemType Directory -Path $target -Force | Out-Null
    foreach ($item in $items) {
        if ($item.PSIsContainer -and $archFolders -contains $item.Name) {
            # an old build folder: merge what's inside it, not the folder itself
            foreach ($child in Get-ChildItem -LiteralPath $item.FullName -Force) { Merge-Item $child (Join-Path $target $child.Name) }
            Remove-Item -LiteralPath $item.FullName -Recurse -Force
        }
        else { Merge-Item $item (Join-Path $target $item.Name) }
    }
    return $true
}

function Merge-Item($item, [string]$destination) {
    if (-not (Test-Path -LiteralPath $destination)) {
        Move-Item -LiteralPath $item.FullName -Destination $destination
    }
    elseif ($item.PSIsContainer) {
        foreach ($child in Get-ChildItem -LiteralPath $item.FullName -Force) {
            Merge-Item $child (Join-Path $destination $child.Name)
        }
        Remove-Item -LiteralPath $item.FullName -Recurse -Force
    }
    else {
        Remove-Item -LiteralPath $item.FullName -Force
    }
}

# -MoveFrom: app folders used to hold their build folders directly (eg. 7-Zip\x64), and some apps had
# folders of their own (eg. "7-Zip Portable", "Notepad++ Portable"); move what's there into this type
# folder (eg. 7-Zip\Installer\x64, 7-Zip\Portable\x86_x64_ARM64) so nothing is downloaded again
function Move-OldLayout([string]$from) {
    if (-not (Test-Path -LiteralPath $from)) { return }
    $from = (Resolve-Path -LiteralPath $from).Path.TrimEnd('\')
    $appFolder = Split-Path -Parent $AppDir
    $isAppFolder = $from -eq $appFolder
    $scripts = @('update.cmd', 'run.cmd', 'install.cmd', 'cli.cmd', '.gitkeep', 'placeholder.file', 'desktop.ini')
    $items = @(Get-ChildItem -LiteralPath $from -Force | Where-Object {
        $item = $_
        if ($scripts -contains $item.Name) { return $false }
        # links to the app's web pages stay with the app folder's scripts
        if ($item.Name -like '*.url') { return $false }
        if ($isAppFolder -and $item.PSIsContainer -and $typeFolders -contains $item.Name) { return $false }
        $true
    })
    if ($items.Count -gt 0) {
        Say "Moving $($items.Count) item(s) from the old layout ($(Split-Path -Leaf $from)) into $(Split-Path -Leaf $appFolder)\$(Split-Path -Leaf $AppDir)..."
        # if this type folder already has a version, the old version/checksum files are out of date
        $hasVersion = [bool](Get-ChildItem -LiteralPath $AppDir -Filter '*.version' -File)
        foreach ($item in $items) {
            if ($hasVersion -and -not $item.PSIsContainer -and ($item.Name -like '*.version' -or $item.Name -eq 'checksums.sfv' -or $item.Name -like '*.par2')) {
                Remove-Item -LiteralPath $item.FullName -Force
                continue
            }
            Merge-Item $item (Join-Path $AppDir $item.Name)
        }
    }
    if (-not $isAppFolder) {
        # an old app folder of its own: keep its web links, then remove it once only its scripts are left
        foreach ($link in Get-ChildItem -LiteralPath $from -Filter '*.url' -File) { Merge-Item $link (Join-Path $appFolder $link.Name) }
        $left = @(Get-ChildItem -LiteralPath $from -Force | Where-Object { $scripts -notcontains $_.Name })
        if ($left.Count -eq 0) {
            Remove-Item -LiteralPath $from -Recurse -Force
            Say "Removed the old $(Split-Path -Leaf $from) folder"
        }
        else { Say "WARNING: couldn't move everything out of $from, so it was left in place" }
    }
}

# true if every build folder this app uses is there and has files in it; if something deleted them
# (eg. by hand), "already up to date" would otherwise leave the app missing
function Test-AppFiles([object[]]$jobs, [switch]$Quiet) {
    foreach ($job in $jobs) {
        if (-not $job.Into) { continue }
        $folder = Join-Path $AppDir $job.Into
        if (-not (Get-ChildItem -LiteralPath $folder -Recurse -File -ErrorAction SilentlyContinue | Select-Object -First 1)) {
            if (-not $Quiet) { Say "The $($job.Into) folder is missing or empty, so downloading again..." }
            return $false
        }
        # PortableApps apps are unpacked (older versions of this script kept just the .paf.exe installer)
        if ($Paf -and -not (Test-Path -LiteralPath (Join-Path $folder 'App'))) {
            if (-not $Quiet) { Say "The PortableApps app in $($job.Into) hasn't been unpacked yet, so updating..." }
            return $false
        }
    }
    return $true
}

# older versions of this script named undated-version files vunknown_<date>.version;
# rename them to v<date>.version and refresh the checksums that list the file name
function Repair-OldVersionName($file) {
    if ($file.Name -notlike 'vunknown_*') { return }
    $newName = $file.Name -replace '^vunknown_', 'v'
    Rename-Item -LiteralPath $file.FullName -NewName $newName
    Say "Renamed $($file.Name) to $newName"
    Write-Checksums
    Write-Parity
}

# ---------------------------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------------------------

Say $Name
Say ('-' * 100)

if ($MoveFrom) {
    try { Move-OldLayout $MoveFrom }
    catch { Say "WARNING: couldn't move the old layout from ${MoveFrom}: $($_.Exception.Message)" }
}

if ($Manual) {
    Say 'This app has to be updated by hand.'
    if ($Page) { Say "Download it from: $Page" }
    if ($Note) { Say $Note }
    Say "Put builds that only run on 64-bit Windows in $AppDir\x64, and anything that runs on 32-bit Windows in $AppDir\x86."
    exit 2
}

$downloads = @()
$script:applying = $false
try {
    Say 'Finding the latest version...'
    if ($PageIndex) {
        $indexHtml = Get-Text $PageIndex
        $releases = @([regex]::Matches($indexHtml, $PageIndexLink, 'IgnoreCase') | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique)
        if (-not $releases) { throw "No release matching '$PageIndexLink' on $PageIndex (the page may have changed)" }
        $release = Select-Highest $releases
        $Page = $Page -f $release
        if ($Page86) { $Page86 = $Page86 -f $release }
        if ($PageArm) { $PageArm = $PageArm -f $release }
    }
    $jobs = @()
    $link = Resolve-Link $Url $Link $Asset
    if (-not $link) { throw 'No download source given (use -Url, -Page/-Link or -GitHub/-Asset)' }
    $jobs += [pscustomobject]@{ Link = $link; SaveAs = $SaveAs; Into = $Into; Inner = $Inner }
    $link86 = Resolve-AltLink $Url86 $Link86 $Asset86 $Page86 $UrlFormat86
    $linkArm = Resolve-AltLink $UrlArm $LinkArm $AssetArm $PageArm $UrlFormatArm
    foreach ($extraLink in ($Extra -split ',') | ForEach-Object { $_.Trim() } | Where-Object { $_ }) {
        $jobs += [pscustomobject]@{ Link = $extraLink; SaveAs = $null; Into = $Into; IsExtra = $true }
    }
    if ($GitHub -and $ExtraAsset) {
        foreach ($extraFile in $script:release.assets | Where-Object { $_.name -match $ExtraAsset -and $_.browser_download_url -ne $link }) {
            $jobs += [pscustomobject]@{ Link = $extraFile.browser_download_url; SaveAs = $null; Into = $Into; IsExtra = $true }
        }
    }
    if ($link86) { $jobs += [pscustomobject]@{ Link = $link86; SaveAs = $SaveAs86; Into = $Into86; Inner = $Inner86 } }
    if ($linkArm) { $jobs += [pscustomobject]@{ Link = $linkArm; SaveAs = $SaveAsArm; Into = $IntoArm; Inner = $InnerArm } }

    # -CheckOnly: show where each link leads and what it is (from its first 1 KB), without changing anything
    if ($CheckOnly) {
        $bad = 0
        foreach ($job in $jobs) {
            $sample = Join-Path $env:TEMP ("USB-Tool-check-" + [Guid]::NewGuid().ToString('N'))
            $curlArgs = @('-sSL', '--fail', '--connect-timeout', '20', '--max-time', '60', '-r', '0-1023', '-A', $userAgent, '-o', $sample, '-D', '-', '-w', '%{url_effective}')
            if ($Referer) { $curlArgs += @('-e', $Referer) }
            $out = @(& $curl @curlArgs $job.Link 2>&1 | ForEach-Object { "$_" })
            $ok = $LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $sample)
            $kind = if ($ok) { Get-FileKind $sample } else { 'failed' }
            $size = ($out | Where-Object { $_ -match '^content-range: bytes \d+-\d+/(\d+)' } | Select-Object -Last 1) -replace '^content-range: bytes \d+-\d+/(\d+).*$', '$1'
            if (-not $size) { $size = ($out | Where-Object { $_ -match '^content-length: (\d+)' } | Select-Object -Last 1) -replace '^content-length: (\d+).*$', '$1' }
            $sizeText = if ($size -match '^\d+$') { '{0:N1} MB' -f ([double]$size / 1MB) } else { '? MB' }
            if ($kind -notin @('exe', 'msi', 'zip', '7z', 'other')) { $bad++ }
            Say ("CHECK {0,-6} {1,-9} {2,-6} {3}" -f $kind, $sizeText, $(if ($job.Into) { $job.Into } else { '.' }), ($out | Select-Object -Last 1))
            Remove-Item -LiteralPath $sample -Force -ErrorAction SilentlyContinue
        }
        exit $(if ($bad) { 1 } else { 0 })
    }

    # files at the top of the app folder, or in a build folder this app no longer uses (eg. x86 after it
    # became x86_x64), belong in its main build folder
    $movedRootFiles = $false
    if ($Into) { $movedRootFiles = Move-RootFiles (Join-Path $AppDir $Into) @($Into, $Into86, $IntoArm) }

    # links scraped from a page or GitHub contain the version, so an unchanged link means nothing new
    $versionFile = Get-ChildItem -LiteralPath $AppDir -Filter '*.version' -File | Select-Object -First 1
    $oldRecord = if ($versionFile) { Get-Content -LiteralPath $versionFile.FullName -Raw } else { '' }
    # version files without a built= line were dated by an older version of this script, so redo them once
    if ($oldRecord -notmatch '(?m)^built=') { $oldRecord = '' }
    # Defender blocked files last time, so try again
    if ($oldRecord -match '(?m)^blocked=') { $oldRecord = '' }
    # after moving files the checksums are out of date, so do a full update
    if ($movedRootFiles) { $oldRecord = '' }
    $oldKey = (($oldRecord -split "`r?`n") | Where-Object { $_ -and $_ -notlike 'built=*' }) -join "`r`n"
    if (-not $Url -and $oldRecord) {
        $unchanged = @($jobs | Where-Object { $oldRecord.Contains("link=$($_.Link)") }).Count -eq $jobs.Count
        if ($unchanged -and (Test-AppFiles $jobs)) {
            Add-DataFolder $jobs
            Repair-OldVersionName $versionFile
            Say "Already up to date"
            exit 0
        }
    }

    # fixed links don't show the version, so compare the server's file date/size/ETag instead of downloading
    foreach ($job in $jobs) { $job | Add-Member -NotePropertyName Stamp -NotePropertyValue $(if ($Url) { Get-RemoteStamp $job.Link } else { '' }) }
    if ($Url -and $oldRecord) {
        $unchanged = @($jobs | Where-Object { $_.Stamp -and $oldRecord.Contains("stamp=$($_.Stamp)") }).Count -eq $jobs.Count
        if ($unchanged -and (Test-AppFiles $jobs)) {
            Add-DataFolder $jobs
            Repair-OldVersionName $versionFile
            Say "Already up to date"
            exit 0
        }
    }

    foreach ($job in $jobs) {
        Say "Downloading $($job.Link)"
        $temp = Join-Path $env:TEMP ("USB-Tool-download-" + [Guid]::NewGuid().ToString('N'))
        $downloads += $temp
        $finalUrl = Get-Download $job.Link $temp
        $kind = Test-Download $temp $job.Link -AllowPlain:([bool]$job.IsExtra)
        $folder = if ($job.Into) { Join-Path $AppDir $job.Into } else { $AppDir }
        $fileName = if ($job.SaveAs) { $job.SaveAs } else { Get-DownloadName $job.Link $finalUrl $kind }
        $job | Add-Member -NotePropertyMembers @{
            Temp = $temp; Kind = $kind; FinalUrl = $finalUrl; Folder = $folder
            Target = (Join-Path $folder $fileName)
            Hash = Get-Sha256 $temp
            # without a Last-Modified header curl leaves the file dated now, which isn't a build date
            ServerDate = $(
                $stamp = (Get-Item -LiteralPath $temp).LastWriteTime
                if ($stamp -lt (Get-Date).AddMinutes(-10)) { $stamp } else { $null }
            )
        }
    }

    # skip everything if the downloads match what was installed last time
    $record = ($jobs | ForEach-Object {
        "link=$($_.Link)"; "url=$($_.FinalUrl)"; "sha256=$($_.Hash)"
        if ($_.Stamp) { "stamp=$($_.Stamp)" }
    }) -join "`r`n"
    $installed = $jobs | Where-Object { $Extract -or $Paf -or (Test-Path -LiteralPath $_.Target) }
    # some links change on every visit (eg. ReNamer's carry a new key each time), so the same files as last
    # time also count as up to date
    $oldHashes = @(($oldRecord -split "`r?`n") | Where-Object { $_ -like 'sha256=*' })
    $sameFiles = $oldHashes.Count -eq $jobs.Count -and (($jobs | ForEach-Object { "sha256=$($_.Hash)" }) -join '|') -eq ($oldHashes -join '|')
    if ($versionFile -and $oldRecord -and @($installed).Count -eq $jobs.Count -and ($oldKey -eq $record -or $sameFiles) -and (Test-AppFiles $jobs -Quiet)) {
        Add-DataFolder $jobs
        Repair-OldVersionName $versionFile
        Say "Already up to date"
        exit 0
    }

    # PortableApps installers: unpack each one now (before touching the old version) so it's ready to run
    if ($Paf) {
        Say 'Unpacking the PortableApps installer...'
        foreach ($job in $jobs) {
            $staging = Join-Path $env:TEMP ("USB-Tool-paf-" + [Guid]::NewGuid().ToString('N'))
            $downloads += $staging
            $pafVersion = Expand-Paf $job.Temp $staging
            $job | Add-Member -NotePropertyMembers @{ Source = $staging; PafVersion = $pafVersion }
        }
    }

    # unpack everything before touching the old version
    if ($Extract) {
        Say 'Extracting...'
        foreach ($job in $jobs) {
            $staging = Join-Path $env:TEMP ("USB-Tool-extract-" + [Guid]::NewGuid().ToString('N'))
            $downloads += $staging
            if ($job.Kind -notin @('zip', '7z')) {
                # a plain -Extra file: staged as-is, so it's copied next to the unzipped app
                New-Item -ItemType Directory -Path $staging | Out-Null
                Copy-Item -LiteralPath $job.Temp -Destination (Join-Path $staging (Split-Path -Leaf $job.Target))
                $job | Add-Member -NotePropertyName Source -NotePropertyValue $staging
                continue
            }
            $job | Add-Member -NotePropertyName Source -NotePropertyValue (Expand-ToStaging $job.Temp $job.Kind $staging $job.Inner)
        }
    }

    Say 'Applying update...'
    $script:applying = $true
    $cleaned = @{}
    foreach ($job in $jobs) {
        if ($Clean -and -not $cleaned[$job.Folder]) {
            # a PortableApps app keeps its settings in Data, next to its launcher
            Clear-OldVersion $job.Folder @(if ($Paf) { 'Data' })
            $cleaned[$job.Folder] = $true
        }
        if ($Extract -or $Paf) {
            # (a PortableApps installer is unpacked straight into the build folder and then deleted with the
            # other downloads, so the app is ready to run)
            Copy-AllowedFiles $job.Source $job.Folder
        }
        else {
            New-Item -ItemType Directory -Path $job.Folder -Force | Out-Null
            Move-Item -LiteralPath $job.Temp -Destination $job.Target -Force
        }
    }
    Add-DataFolder $jobs

    Say 'Updating version file...'
    Get-ChildItem -LiteralPath $AppDir -Filter '*.version' -File | Remove-Item -Force
    $version = Get-Version $jobs
    $buildDate = Get-BuildDate $jobs
    # without a version number the file is just dated, eg. v2026-11-11.version
    $versionName = if ($version -eq 'unknown') { 'v{0}.version' -f $buildDate.ToString('yyyy-MM-dd') }
        else { 'v{0}_{1}.version' -f $version, $buildDate.ToString('yyyy-MM-dd') }
    $versionPath = Join-Path $AppDir $versionName
    $versionText = $record + "`r`nbuilt=" + $buildDate.ToString('yyyy-MM-dd')
    # files Defender blocked are noted so the next run tries again (eg. after adding an exclusion)
    if ($script:blocked.Count -gt 0) { $versionText += "`r`nblocked=" + ($script:blocked -join ',') }
    [IO.File]::WriteAllText($versionPath, $versionText)
    Say "Version: $version (built $($buildDate.ToString('yyyy-MM-dd')))"

    Say 'Updating checksums...'
    $blockedBefore = $script:blocked.Count
    Write-Checksums
    if ($script:blocked.Count -gt $blockedBefore) {
        # more files turned out to be blocked; record them so the next run retries, then redo the checksums
        $versionText = $record + "`r`nbuilt=" + $buildDate.ToString('yyyy-MM-dd') + "`r`nblocked=" + ($script:blocked -join ',')
        [IO.File]::WriteAllText($versionPath, $versionText)
        Write-Checksums
    }
    Say 'Updating parity data...'
    Write-Parity

    if ($script:blocked.Count -gt 0) {
        Say "WARNING: Windows Defender blocked $($script:blocked.Count) file(s), so they weren't copied: $($script:blocked -join ', ')"
        Say 'To keep them, add a Defender exclusion for this app folder and %TEMP%, then run the update again.'
        Say 'Done (with blocked files)'
        exit 3
    }
    Say 'Done'
    exit 0
}
catch {
    $message = $_.Exception.Message
    if ($message -match 'virus or potentially unwanted software') {
        $message = 'Windows Defender blocked a file in this app as unwanted software (common for password-recovery and repair tools). ' +
            'Add a Defender exclusion for this app folder and %TEMP%, or update it by hand.'
    }
    Say "FAILED: $message"
    if ($script:applying) {
        # forget the recorded version so the next run tries again
        Get-ChildItem -LiteralPath $AppDir -Filter '*.version' -File -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
        Say 'The update failed part-way through, so check this app folder.'
    }
    else { Say 'Nothing was changed; the old version (if there was one) is still in place.' }
    exit 1
}
finally {
    foreach ($d in $downloads) { Remove-Item -LiteralPath $d -Recurse -Force -ErrorAction SilentlyContinue }
}
