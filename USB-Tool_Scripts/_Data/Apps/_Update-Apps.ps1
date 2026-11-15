# Update-Apps - runs every app's update.cmd for Update-Tool.cmd, several at once
# --------------------------------------------------
# Most of an app's check is waiting for its website, so running a few at a time makes the whole update much
# quicker. Each app's output goes to its own log (-RunDir\logs), and a line is shown as each one finishes.
# Writes to -RunDir, for Update-Tool's summary and its report (_Update-Report.ps1):
#   plan.txt     every app folder it will try, in order (folders starting with _ are notes, not apps)
#   apps.txt     a line per app as it finishes: <update.cmd's exit code, or skip>*<name>
#   state.txt    step=apps, then start=<n>*<name> as each app starts, and stopped=1 if it's stopped early
# Apps whose update.cmd refers to another app's folder (eg. -MoveFrom "%~dp0..\7-Zip Portable") don't run at the
# same time as that app.
# Ctrl+C: each app's update gets it too, and stops tidily (_Update-App.ps1 notes what it was doing). The apps
# carry on to their next download if they have one ("Terminate batch job" reads no answer from their log), so
# any still going a few seconds later are ended; an app ended while replacing its files has its
# update-in-progress.txt left, so its next update redoes it.
param(
    [Parameter(Mandatory = $true)][string]$AppsDir,
    [Parameter(Mandatory = $true)][string]$RunDir,
    [int]$Parallel = 6
)

$ErrorActionPreference = 'Stop'
if ($Parallel -lt 1) { $Parallel = 1 }
$AppsDir = $AppsDir.TrimEnd('\')
$logDir = Join-Path $RunDir 'logs'
New-Item -ItemType Directory -Path $logDir -Force | Out-Null
# (the text files are in the console's code page, as Update-Tool.cmd reads them)
$encoding = try { [Console]::OutputEncoding } catch { [Text.Encoding]::Default }
if ($encoding.CodePage -eq 65001) { $encoding = New-Object Text.UTF8Encoding $false }
function Add-Line([string]$name, [string]$text) { [IO.File]::AppendAllText((Join-Path $RunDir $name), "$text`r`n", $encoding) }

# the app folders, by name (folders starting with _ are notes, not apps). A folder with an update.cmd is an app;
# one without is a group of apps (eg. Nirsoft\ProduKey, Microsoft\Office\2024), so the apps inside it are found
# too, named by their path from here (up to 4 folders down). A folder here without an update.cmd that has no
# apps inside it is listed as is (skipped, as it can't be updated). Download folders (Installer, Portable, CLI)
# are never looked in, as a downloaded app can have an update.cmd of its own (eg. WSUS Offline's client\Update.cmd).
function Find-Apps([string]$folder, [string]$prefix = '', [int]$depth = 1) {
    foreach ($dir in Get-ChildItem -LiteralPath $folder -Directory | Where-Object { $_.Name -notlike '_*' -and ($depth -eq 1 -or $_.Name -notin @('Installer', 'Portable', 'CLI')) } | Sort-Object Name) {
        $name = $prefix + $dir.Name
        if (Test-Path -LiteralPath (Join-Path $dir.FullName 'update.cmd')) { [pscustomobject]@{ Name = $name; Folder = $dir.FullName }; continue }
        $inside = if ($depth -lt 4) { @(Find-Apps $dir.FullName "$name\" ($depth + 1)) } else { @() }
        if ($inside) { $inside } elseif ($depth -eq 1) { [pscustomobject]@{ Name = $name; Folder = $dir.FullName } }
    }
}
$apps = @(Find-Apps $AppsDir | ForEach-Object -Begin { $n = 0 } -Process {
    $n++
    $script = Join-Path $_.Folder 'update.cmd'
    $hasScript = Test-Path -LiteralPath $script
    # other app folders its update.cmd uses (eg. the folder it moves an older copy from, "%~dp0..\7-Zip Portable"),
    # named from _Data\Apps like the apps are (the shared helper, a folder or more up, isn't one)
    $parent = Split-Path -Parent $_.Name
    $uses = if ($hasScript) {
        @([regex]::Matches([IO.File]::ReadAllText($script), '%~dp0\.\.\\([^"%]+)') | ForEach-Object {
            $path = $_.Groups[1].Value.Trim().TrimEnd('\')
            $up = $parent
            while ($path -match '^\.\.\\(.*)$') { $path = $Matches[1]; $up = if ($up) { Split-Path -Parent $up } else { '' } }
            # (each folder along the path, as it may go on into the app's own folders, eg. "7-Zip\Portable")
            $sofar = $up
            foreach ($part in $path -split '\\' | Where-Object { $_ }) {
                if ($part -like '_*') { break }
                $sofar = if ($sofar) { "$sofar\$part" } else { $part }
                $sofar
            }
        })
    } else { @() }
    [pscustomobject]@{ Index = $n; Name = $_.Name; Show = $_.Name -replace '\\', ' '; Folder = $_.Folder; HasScript = $hasScript; Uses = $uses }
})
$total = $apps.Count
foreach ($app in $apps) { Add-Line 'plan.txt' $app.Name }
Add-Line 'state.txt' 'step=apps'
$names = @{}; foreach ($app in $apps) { $names[$app.Name] = $true }
# (both ways: an app doesn't run alongside one it uses, or one that uses it)
$clashes = @{}
foreach ($app in $apps) {
    foreach ($other in $app.Uses | Where-Object { $names[$_] -and $_ -ne $app.Name }) {
        $clashes[$app.Name] = @($clashes[$app.Name] | Where-Object { $_ }) + $other
        $clashes[$other] = @($clashes[$other] | Where-Object { $_ }) + $app.Name
    }
}

# what each app's update recorded (_Update-App.ps1 adds a line per part to this file), read as it grows
$resultsFile = $env:USB_TOOL_REPORT
$resultsRead = 0
$parts = @{}
function Read-NewResults {
    if (-not $resultsFile -or -not (Test-Path -LiteralPath $resultsFile)) { return }
    try {
        $stream = [IO.File]::Open($resultsFile, 'Open', 'Read', 'ReadWrite')
        try {
            $stream.Position = $script:resultsRead
            $reader = New-Object IO.StreamReader($stream, (New-Object Text.UTF8Encoding $false))
            $text = $reader.ReadToEnd()
        }
        finally { $stream.Close() }
    }
    catch { return }
    # (only whole lines; a line still being written is read next time)
    $end = $text.LastIndexOf("`n")
    if ($end -lt 0) { return }
    $script:resultsRead += (New-Object Text.UTF8Encoding $false).GetByteCount($text.Substring(0, $end + 1))
    foreach ($line in $text.Substring(0, $end + 1) -split "`r?`n" | Where-Object { $_.Trim() }) {
        try { $part = $line | ConvertFrom-Json } catch { continue }
        $script:parts[$part.app] = @($script:parts[$part.app]) + $part
    }
}

$width = [Math]::Min(42, ($apps | ForEach-Object { $_.Show.Length } | Measure-Object -Maximum).Maximum)
$done = 0
function Show-Line([object]$app, [string]$text, [string]$colour, [double]$seconds = -1) {
    $name = if ($app.Show.Length -gt $width) { $app.Show.Substring(0, $width - 1) + '~' } else { $app.Show }
    $time = if ($seconds -ge 0) { ' ({0:N0} s)' -f $seconds } else { '' }
    Write-Host ("[{0,3}/{1}] {2} " -f $script:done, $total, $name.PadRight($width)) -NoNewline
    Write-Host "$text$time" -ForegroundColor $colour
}

# one finished app: record it, and say how it went
function Complete-App([object]$run) {
    $app = $run.App
    $code = $run.Process.ExitCode
    Add-Line 'apps.txt' "$code*$($app.Name)"
    $script:done++
    Read-NewResults
    $own = @($script:parts[$app.Name] | Where-Object { $_ })
    $seconds = ((Get-Date) - $run.Started).TotalSeconds
    $updated = @($own | Where-Object { $_.status -in @('updated', 'blocked') })
    $versions = ($updated | ForEach-Object { if ($_.version) { $_.version } elseif ($_.built) { $_.built } } | Select-Object -Unique) -join ', '
    switch ("$code") {
        '0' { if ($updated) { Show-Line $app "updated$(if ($versions) { " to $versions" })" Green $seconds } else { Show-Line $app 'up to date' Gray $seconds } }
        '2' { Show-Line $app 'needs updating by hand' Yellow $seconds }
        '3' { Show-Line $app "updated$(if ($versions) { " to $versions" }), but Windows Defender blocked some files" Yellow $seconds }
        default {
            if ($own | Where-Object { $_.status -eq 'cancelled' }) { Show-Line $app 'stopped' Red $seconds; break }
            # why: the helper's message, or the last thing update.cmd said
            $why = ($own | Where-Object { $_.status -eq 'failed' -and $_.message } | Select-Object -First 1).message
            if (-not $why) {
                $why = (Get-Content -LiteralPath $run.Log -ErrorAction SilentlyContinue | Where-Object { $_.Trim() -and $_ -notmatch '^[#\s.%0-9]*$' } | Select-Object -Last 1)
            }
            Show-Line $app "FAILED$(if ($why) { ": $("$why".Trim())" })" Red $seconds
        }
    }
}

function Start-App([object]$app) {
    # (characters cmd would read as variables or escapes are left out of the log's name)
    $logName = '{0:D3} {1}.log' -f $app.Index, ($app.Show -replace '[%!^&]', '_')
    $log = Join-Path $logDir $logName
    $psi = New-Object Diagnostics.ProcessStartInfo
    $psi.FileName = Join-Path $env:SystemRoot 'System32\cmd.exe'
    # .\ is needed on PCs that don't search the current folder for commands; no input, so nothing waits on a key
    $psi.Arguments = "/d /s /c `"`".\update.cmd`" /nopause >`"$log`" 2>&1 <nul`""
    $psi.WorkingDirectory = $app.Folder
    $psi.UseShellExecute = $false
    Add-Line 'state.txt' "start=$($app.Index)*$($app.Name)"
    return [pscustomobject]@{ App = $app; Process = [Diagnostics.Process]::Start($psi); Started = Get-Date; Log = $log }
}

$queue = New-Object Collections.Generic.List[object]
foreach ($app in $apps) { $queue.Add($app) }
$running = New-Object Collections.Generic.List[object]
$finished = $false
try {
    while ($queue.Count -or $running.Count) {
        foreach ($run in @($running | Where-Object { $_.Process.HasExited })) {
            [void]$running.Remove($run)
            Complete-App $run
        }
        while ($running.Count -lt $Parallel -and $queue.Count) {
            $busy = @($running | ForEach-Object { $_.App.Name })
            $next = $queue | Where-Object { -not ($clashes[$_.Name] | Where-Object { $busy -contains $_ }) } | Select-Object -First 1
            if (-not $next) { break }
            [void]$queue.Remove($next)
            # (an old folder may have been moved into its app by now, eg. "TechPowerUp GPU-Z Portable")
            if (-not $next.HasScript -or -not (Test-Path -LiteralPath (Join-Path $next.Folder 'update.cmd'))) {
                Add-Line 'apps.txt' "skip*$($next.Name)"
                $script:done++
                Show-Line $next 'skipped (no update.cmd)' DarkGray
                continue
            }
            try { $running.Add((Start-App $next)) }
            catch {
                Add-Line 'apps.txt' "1*$($next.Name)"
                $script:done++
                Show-Line $next "FAILED: couldn't start its update.cmd ($($_.Exception.Message))" Red
            }
        }
        $Host.UI.RawUI.WindowTitle = "USB Tool Updater - apps $done of $total done, $($running.Count) updating"
        Start-Sleep -Milliseconds 150
    }
    $finished = $true
}
finally {
    if (-not $finished) {
        # stopped early (Ctrl+C): the apps' updates got it too, and stop tidily; give them a moment, then end
        # any still going (eg. on to their next download) and everything they started
        Add-Line 'state.txt' 'stopped=1'
        Write-Host ''
        Write-Host 'Stopping the apps still updating...' -ForegroundColor Yellow
        $until = (Get-Date).AddSeconds(8)
        while (($running | Where-Object { -not $_.Process.HasExited }) -and (Get-Date) -lt $until) { Start-Sleep -Milliseconds 200 }
        foreach ($run in @($running)) {
            if ($run.Process.HasExited) { Complete-App $run; continue }
            & "$env:SystemRoot\System32\taskkill.exe" /PID $run.Process.Id /T /F 2>&1 | Out-Null
            Show-Line $run.App 'stopped' Red ((Get-Date) - $run.Started).TotalSeconds
        }
        Write-Host "$($queue.Count) app$(if ($queue.Count -ne 1) { 's' }) weren't started." -ForegroundColor Yellow
    }
    $Host.UI.RawUI.WindowTitle = 'USB Tool Updater'
}
