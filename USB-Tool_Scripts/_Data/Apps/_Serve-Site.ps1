# Serve-Site - shows a site copied for offline use (an app's -Site copy, see _Update-App.ps1) in the browser
# --------------------------------------------------
# Some sites only work from a web server, not opened as files: eg. the COPS Manual (a Quartz site) links to its
# pages without .html and loads its menu and search with scripts, which browsers block for files. So this
# serves the copy at http://localhost:<port>/ (this PC only), finding pages the way GitHub Pages does
# (a/b is a/b.html, a/ is a/index.html), and opens it in the browser.
# It keeps running while the site is in use, and stops by itself after -IdleMinutes without a request (or
# close its window).
#   -Folder <path>       the copy (eg. _Data\Apps\WelFedTed\COPS Manual\Portable\Any)
#   -Title <text>        for the window
#   -InPrivate           open it in Microsoft Edge's InPrivate mode, rather than the default browser
#   -Port <n>            use this port (default: a free one); -NoBrowser: don't open it (for testing)
param(
    [Parameter(Mandatory = $true)][string]$Folder,
    [string]$Title = 'Offline site',
    [switch]$InPrivate,
    [int]$IdleMinutes = 60,
    [int]$Port = 0,
    [switch]$NoBrowser
)
$ErrorActionPreference = 'Stop'
$Folder = (Resolve-Path -LiteralPath $Folder).Path.TrimEnd('\')
$Host.UI.RawUI.WindowTitle = "$Title (offline copy) - close this window when you're done"

$types = @{
    '.html' = 'text/html; charset=utf-8'; '.htm' = 'text/html; charset=utf-8'; '.css' = 'text/css; charset=utf-8'
    '.js' = 'text/javascript; charset=utf-8'; '.mjs' = 'text/javascript; charset=utf-8'; '.json' = 'application/json; charset=utf-8'
    '.xml' = 'application/xml'; '.txt' = 'text/plain; charset=utf-8'; '.svg' = 'image/svg+xml'; '.png' = 'image/png'
    '.jpg' = 'image/jpeg'; '.jpeg' = 'image/jpeg'; '.gif' = 'image/gif'; '.webp' = 'image/webp'; '.ico' = 'image/x-icon'
    '.woff' = 'font/woff'; '.woff2' = 'font/woff2'; '.ttf' = 'font/ttf'; '.otf' = 'font/otf'; '.pdf' = 'application/pdf'
}

# a port on this PC only (http://localhost/ needs no admin rights, unlike other addresses); Windows picks a
# free one, as PCs keep different blocks of ports for themselves (eg. Hyper-V's), which can't be used
$listener = $null; $problem = ''
foreach ($try in 1..5) {
    $use = $Port
    if (-not $use) {
        $probe = New-Object Net.Sockets.TcpListener([Net.IPAddress]::Loopback, 0)
        $probe.Start(); $use = $probe.LocalEndpoint.Port; $probe.Stop()
    }
    $candidate = New-Object Net.HttpListener
    $candidate.Prefixes.Add("http://localhost:$use/")
    try { $candidate.Start(); $listener = $candidate; break }
    catch { $problem = $_.Exception.Message; $candidate.Close(); if ($Port) { break } }
}
if (-not $listener) { Write-Host "Couldn't start the offline copy's web server: $problem"; Read-Host 'Press Enter to close'; exit 1 }
$url = $listener.Prefixes | Select-Object -First 1

# the file for a request, as GitHub Pages finds it; $null if there's none (or it's outside the copy)
function Find-File([string]$path) {
    $rel = [Uri]::UnescapeDataString($path).TrimStart('/') -replace '/', '\'
    $full = [IO.Path]::GetFullPath((Join-Path $Folder $rel))
    if (-not ($full + '\').StartsWith($Folder + '\', [StringComparison]::OrdinalIgnoreCase)) { return $null }
    foreach ($candidate in @($full, "$full.html", (Join-Path $full 'index.html'))) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
    }
    return $null
}

Write-Host "$Title (offline copy)"
Write-Host "Showing $Folder"
Write-Host "at $url"
Write-Host ''
Write-Host "Close this window when you're done (it also stops by itself after $IdleMinutes minutes unused)."
if ($NoBrowser) { }
elseif ($InPrivate) { Start-Process 'msedge.exe' -ArgumentList '--inprivate', $url }
else { Start-Process $url }

try {
    $pending = $listener.GetContextAsync()
    while ($true) {
        if (-not $pending.Wait([TimeSpan]::FromMinutes($IdleMinutes))) { Write-Host 'Unused for a while, so stopping.'; break }
        $context = $pending.Result
        $pending = $listener.GetContextAsync()
        $response = $context.Response
        try {
            $file = Find-File $context.Request.Url.AbsolutePath
            if (-not $file) {
                $response.StatusCode = 404
                $file = Find-File '/404.html'
            }
            if ($file) {
                $bytes = [IO.File]::ReadAllBytes($file)
                $type = $types[[IO.Path]::GetExtension($file).ToLower()]
                $response.ContentType = if ($type) { $type } else { 'application/octet-stream' }
                $response.ContentLength64 = $bytes.Length
                $response.OutputStream.Write($bytes, 0, $bytes.Length)
            }
        }
        catch { }
        finally { try { $response.Close() } catch { } }
    }
}
finally { $listener.Close() }
