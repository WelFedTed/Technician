# Update-App - shared updater for the apps in _Data\Apps
# --------------------------------------------------
# Each app's update.cmd calls this with the app's download details.
# It downloads the latest version, checks the download is real (not an error page or empty file)
# before touching the old version, then rewrites the .version file, checksums.sfv and parity data.
# The version file is named v<version>_<build date>.version, where the build date comes from the
# GitHub release, the files inside the archive, the server's Last-Modified date or the exe itself.
#
# Where to get the app (pick one):
#   -Url <url>                        a fixed download link
#   -Page <url> -Link <regex>         scrape the link from a web page; the highest version number wins
#       [-UrlFormat <fmt>]            build the link from the regex's first group, eg. "https://x/app_{0}.zip"
#   -GitHub <owner/repo> -Asset <regex>   an asset of the latest GitHub release
#   -Manual [-Page <url>] [-Note <text>]  can't be downloaded automatically; prints where to get it
# Optional 32-bit download from the same source: -Url86 / -Link86 / -Asset86,
#   or -UrlFormat86 to build it from the same version -Link captured
# Extra files saved next to the main one, named as in their links: -Extra "url1,url2"
#
# What to do with it:
#   -SaveAs <name>, -SaveAs86 <name>  save a single file under this name (default: name from the link)
#   -Extract                          unzip it (.zip or .7z)
#   -Into <folder>, -Into86 <folder>  the subfolder for each build:
#                                     x64 = only runs on 64-bit Windows, x86 = runs on 32-bit Windows
#                                     (combined downloads, installers and scripts that run on both go in x86)
#                                     Anything else left at the top of the app folder is moved into the -Into folder
#   -Flatten                          if the archive has one top folder, use what's inside it
#   -Clean                            delete the old version's files first (keeps update.cmd, *.url, run.cmd and -Keep)
#   -Keep "a,b"                       extra file/folder names to keep when cleaning
#   -Referer <url>                    some sites only allow downloads from their own pages
#   -VersionFrom <file>               read the version from this file instead of the link
#
# Exit codes: 0 = updated or already up to date, 1 = failed, 2 = needs a manual update

param(
    [Parameter(Mandatory = $true)][string]$Name,
    [string]$AppDir = (Get-Location).Path,
    [string]$Url, [string]$Url86, [string]$Extra,
    [string]$Page, [string]$Link, [string]$Link86, [string]$UrlFormat, [string]$UrlFormat86,
    [string]$GitHub, [string]$Asset, [string]$Asset86,
    [switch]$Manual, [string]$Note,
    [string]$SaveAs, [string]$SaveAs86,
    [switch]$Extract, [string]$Into, [string]$Into86,
    [switch]$Flatten, [switch]$Clean, [string]$Keep,
    [string]$Referer,
    [string]$VersionFrom
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36'
$curl = Join-Path $env:SystemRoot 'System32\curl.exe'
$toolsDir = Join-Path $env:LOCALAPPDATA 'USB-Tool\tools'
$AppDir = (Resolve-Path -LiteralPath $AppDir).Path
$alwaysKeep = @('update.cmd', '*.url', 'run.cmd', '*.version', 'checksums.sfv', '*.par2')

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
function Find-PageLink([string]$pattern) {
    $html = Get-Text $Page
    $found = [regex]::Matches($html, $pattern, 'IgnoreCase') | ForEach-Object {
        if ($UrlFormat) { $UrlFormat -f $_.Groups[1].Value } else { $_.Value }
    } | Select-Object -Unique
    if (-not $found) { throw "No link matching '$pattern' on $Page (the page may have changed)" }
    $best = Select-Highest @($found)
    # remember the version the regex captured, for -UrlFormat86
    if ($UrlFormat) {
        $script:pageVersion = [regex]::Matches($html, $pattern, 'IgnoreCase') |
            Where-Object { ($UrlFormat -f $_.Groups[1].Value) -eq $best } |
            Select-Object -First 1 | ForEach-Object { $_.Groups[1].Value }
    }
    return ([Uri]::new([Uri]$Page, $best)).AbsoluteUri
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
    $name = if ($fromLink -match '\.[A-Za-z0-9]{2,4}$') { $fromLink } else { $fromFinal }
    if ($name -notmatch '\.[A-Za-z0-9]{2,4}$' -and $kind -in @('exe', 'msi', 'zip', '7z')) { $name += ".$kind" }
    foreach ($bad in [IO.Path]::GetInvalidFileNameChars()) { $name = $name.Replace([string]$bad, '_') }
    return $name
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
    if ($start.StartsWith('<')) { return 'html' }
    return 'other'
}

function Test-Download([string]$path, [string]$address) {
    $size = (Get-Item -LiteralPath $path).Length
    if ($size -lt 10KB) { throw "Download is only $size bytes, probably an error page: $address" }
    $kind = Get-FileKind $path
    if ($kind -eq 'html') { throw "Download is a web page, not the app (the link may have changed): $address" }
    if ($Extract -and $kind -notin @('zip', '7z')) { throw "Expected a .zip or .7z but got a $kind file: $address" }
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

function Clear-OldVersion([string]$folder) {
    if (-not (Test-Path -LiteralPath $folder)) { return }
    $keepList = $alwaysKeep + @(($Keep -split '[,;]') | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    Get-ChildItem -LiteralPath $folder -Force | Where-Object {
        $item = $_
        -not ($keepList | Where-Object { $item.Name -like $_ })
    } | Remove-Item -Recurse -Force
}

# extracts to a temp folder and returns the folder holding the app's files
function Expand-ToStaging([string]$archive, [string]$kind, [string]$staging) {
    New-Item -ItemType Directory -Path $staging | Out-Null
    if ($kind -eq '7z') {
        $sevenZip = Get-Tool '7zr.exe' 'https://www.7-zip.org/a/7zr.exe'
        & $sevenZip x $archive "-o$staging" -y | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "Couldn't extract the download (7zr exit code $LASTEXITCODE)" }
    }
    else {
        [IO.Compression.ZipFile]::ExtractToDirectory($archive, $staging)
    }
    $top =@(Get-ChildItem -LiteralPath $staging -Force)
    if ($top.Count -eq 0) { throw 'The downloaded archive is empty' }
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

function Get-Version([object[]]$jobs) {
    if ($VersionFrom) {
        $file = Join-Path $AppDir $VersionFrom
        if (Test-Path -LiteralPath $file) {
            $v = (Get-Item -LiteralPath $file).VersionInfo.FileVersionRaw
            if ($v -and $v.ToString() -ne '0.0.0.0') { return $v.ToString() }
        }
    }
    if ($script:release) { return ($script:release.tag_name -replace '^v', '') }
    foreach ($job in $jobs) {
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
    $rows = foreach ($f in $files) { [pscustomobject]@{ Path = $f.FullName.Substring($AppDir.Length).TrimStart('\'); Crc = [UsbToolCrc32]::OfFile($f.FullName) } }
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

# moves everything at the top of the app folder (except update.cmd, *.url, run.cmd, version/checksum/parity
# files and the x64/x86 folders) into $target; where $target already has the same item, the old copy is dropped
function Move-RootFiles([string]$target) {
    $keepAtRoot = $alwaysKeep + @('x64', 'x86')
    $items = @(Get-ChildItem -LiteralPath $AppDir -Force | Where-Object {
        $item = $_
        -not ($keepAtRoot | Where-Object { $item.Name -like $_ })
    })
    if ($items.Count -eq 0) { return $false }
    Say "Moving $($items.Count) item(s) from the app folder into its $(Split-Path -Leaf $target) folder..."
    New-Item -ItemType Directory -Path $target -Force | Out-Null
    foreach ($item in $items) { Merge-Item $item (Join-Path $target $item.Name) }
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

if ($Manual) {
    Say 'This app has to be updated by hand.'
    if ($Page) { Say "Download it from: $Page" }
    if ($Note) { Say $Note }
    Say 'Put builds that only run on 64-bit Windows in the x64 folder, and anything that runs on 32-bit Windows in x86.'
    exit 2
}

$downloads = @()
$script:applying = $false
try {
    Say 'Finding the latest version...'
    $jobs = @()
    $link = Resolve-Link $Url $Link $Asset
    if (-not $link) { throw 'No download source given (use -Url, -Page/-Link or -GitHub/-Asset)' }
    $jobs += [pscustomobject]@{ Link = $link; SaveAs = $SaveAs; Into = $Into }
    $link86 = Resolve-Link $Url86 $Link86 $Asset86
    if (-not $link86 -and $UrlFormat86 -and $script:pageVersion) { $link86 = $UrlFormat86 -f $script:pageVersion }
    foreach ($extraLink in ($Extra -split ',') | ForEach-Object { $_.Trim() } | Where-Object { $_ }) {
        $jobs += [pscustomobject]@{ Link = $extraLink; SaveAs = $null; Into = $Into }
    }

    # files left at the top of the app folder (the old layout) belong in its x64/x86 folder
    $movedRootFiles = $false
    if ($Into) { $movedRootFiles = Move-RootFiles (Join-Path $AppDir $Into) }
    if ($link86) { $jobs += [pscustomobject]@{ Link = $link86; SaveAs = $SaveAs86; Into = $Into86 } }

    # links scraped from a page or GitHub contain the version, so an unchanged link means nothing new
    $versionFile = Get-ChildItem -LiteralPath $AppDir -Filter '*.version' -File | Select-Object -First 1
    $oldRecord = if ($versionFile) { Get-Content -LiteralPath $versionFile.FullName -Raw } else { '' }
    # version files without a built= line were dated by an older version of this script, so redo them once
    if ($oldRecord -notmatch '(?m)^built=') { $oldRecord = '' }
    # after moving files the checksums are out of date, so do a full update
    if ($movedRootFiles) { $oldRecord = '' }
    $oldKey = (($oldRecord -split "`r?`n") | Where-Object { $_ -and $_ -notlike 'built=*' }) -join "`r`n"
    if (-not $Url -and $oldRecord) {
        $unchanged = @($jobs | Where-Object { $oldRecord.Contains("link=$($_.Link)") }).Count -eq $jobs.Count
        if ($unchanged) {
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
        $kind = Test-Download $temp $job.Link
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
    $record = ($jobs | ForEach-Object { "link=$($_.Link)"; "url=$($_.FinalUrl)"; "sha256=$($_.Hash)" }) -join "`r`n"
    $installed = $jobs | Where-Object { $Extract -or (Test-Path -LiteralPath $_.Target) }
    if ($versionFile -and $oldRecord -and @($installed).Count -eq $jobs.Count -and $oldKey -eq $record) {
        Repair-OldVersionName $versionFile
        Say "Already up to date"
        exit 0
    }

    # unpack everything before touching the old version
    if ($Extract) {
        Say 'Extracting...'
        foreach ($job in $jobs) {
            $staging = Join-Path $env:TEMP ("USB-Tool-extract-" + [Guid]::NewGuid().ToString('N'))
            $downloads += $staging
            $job | Add-Member -NotePropertyName Source -NotePropertyValue (Expand-ToStaging $job.Temp $job.Kind $staging)
        }
    }

    Say 'Applying update...'
    $script:applying = $true
    $cleaned = @{}
    foreach ($job in $jobs) {
        if ($Clean -and -not $cleaned[$job.Folder]) { Clear-OldVersion $job.Folder; $cleaned[$job.Folder] = $true }
        if ($Extract) {
            New-Item -ItemType Directory -Path $job.Folder -Force | Out-Null
            Get-ChildItem -LiteralPath $job.Source -Force | Copy-Item -Destination $job.Folder -Recurse -Force
        }
        else {
            New-Item -ItemType Directory -Path $job.Folder -Force | Out-Null
            Move-Item -LiteralPath $job.Temp -Destination $job.Target -Force
        }
    }

    Say 'Updating version file...'
    Get-ChildItem -LiteralPath $AppDir -Filter '*.version' -File | Remove-Item -Force
    $version = Get-Version $jobs
    $buildDate = Get-BuildDate $jobs
    # without a version number the file is just dated, eg. v2026-11-11.version
    $versionName = if ($version -eq 'unknown') { 'v{0}.version' -f $buildDate.ToString('yyyy-MM-dd') }
        else { 'v{0}_{1}.version' -f $version, $buildDate.ToString('yyyy-MM-dd') }
    $versionPath = Join-Path $AppDir $versionName
    [IO.File]::WriteAllText($versionPath, $record + "`r`nbuilt=" + $buildDate.ToString('yyyy-MM-dd'))
    Say "Version: $version (built $($buildDate.ToString('yyyy-MM-dd')))"

    Say 'Updating checksums...'
    Write-Checksums
    Say 'Updating parity data...'
    Write-Parity

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
