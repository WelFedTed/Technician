# Update-Report - the HTML report Update-Tool.cmd opens when it finishes
# --------------------------------------------------
# Update-Tool.cmd runs this twice, with a folder in %TEMP% (-DataDir) for the run's details:
#   -Begin                        at the start: notes the time and the free space, and starts the watcher
#   (without -Begin)              at the end: makes the report in -OutDir, named for when the run started
#                                 (eg. Update-Report_2026-11-15_18-37-29.html, so each run's is kept), and
#                                 puts its path in report.txt in -DataDir (without -OutDir, as from an older
#                                 Update-Tool.cmd: Update-Report.html in -DataDir); it's made from
#       results.jsonl             a line per app part, written by _Update-App.ps1 (status, versions, links)
#       apps.txt                  a line per app folder, written by Update-Tool.cmd: <exit code or skip>*<name>
#       plan.txt                  every app folder the run was going to try, in order
#       state.txt                 how far the run got: step=scripts / app*<n>*<name> / finish / report,
#                                 and scripts=, selfUpdate=, stamp= once they're known
# The report has the run's numbers, then what needs doing by hand (with download links and the scripts to
# run, eg. Aseprite's build.cmd), then what was updated and every app's state.
# The watcher (-Watch, in its own hidden window, so Ctrl+C in Update-Tool's window doesn't stop it too):
# Update-Tool keeps running.lock open while it works. If it lets go (or its window closes) before the report
# was made, the run was stopped early, eg. with Ctrl+C, so the watcher makes the report itself, saying where
# it stopped and which apps weren't tried, and opens it.
param(
    [Parameter(Mandatory = $true)][string]$DataDir,
    [string]$OutDir,
    [Parameter(Mandatory = $true)][string]$Root,
    [switch]$Begin,
    [switch]$Watch,
    [int]$ParentPid = 0,
    [string]$Scripts = 'skipped',
    [string]$SelfUpdate = '0',
    [string]$DoScripts = '1',
    [string]$DoApps = '1',
    [string]$Stamp = ''
)

$ErrorActionPreference = 'Stop'
$Root = [IO.Path]::GetFullPath($Root.TrimEnd('.'))
if (-not $Root.EndsWith('\')) { $Root += '\' }
$appsDir = Join-Path $Root '_Data\Apps'

function Get-Free([string]$path) {
    try { return ([IO.DriveInfo]([IO.Path]::GetPathRoot($path))).AvailableFreeSpace } catch { return $null }
}

# the report's file: named for when the run started (from start.json), so each run's is kept
function Get-ReportPath {
    if (-not $OutDir) { return Join-Path $DataDir 'Update-Report.html' }
    $when = Get-Date
    $startFile = Join-Path $DataDir 'start.json'
    if (Test-Path -LiteralPath $startFile) {
        try { $when = [DateTime]::Parse((Get-Content -LiteralPath $startFile -Raw | ConvertFrom-Json).started) } catch { }
    }
    return Join-Path $OutDir ('Update-Report_{0:yyyy-MM-dd_HH-mm-ss}.html' -f $when)
}

if ($Begin) {
    New-Item -ItemType Directory -Path $DataDir -Force | Out-Null
    $start = [ordered]@{ started = (Get-Date).ToString('o'); free = (Get-Free $Root); systemFree = (Get-Free $env:SystemDrive); doScripts = $DoScripts; doApps = $DoApps }
    [IO.File]::WriteAllText((Join-Path $DataDir 'start.json'), ($start | ConvertTo-Json -Compress))
    try {
        # (this was started by Update-Tool's own cmd.exe, so the watcher can also tell if its window closes)
        $cmdPid = [int](Get-CimInstance Win32_Process -Filter "ProcessId=$PID").ParentProcessId
        $watchArgs = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Watch -DataDir `"$DataDir`" -Root `"$($Root).`" -ParentPid $cmdPid"
        if ($OutDir) { $watchArgs += " -OutDir `"$OutDir`"" }
        Start-Process -FilePath (Join-Path $PSHOME 'powershell.exe') -ArgumentList $watchArgs -WindowStyle Hidden
    }
    catch { Write-Host "WARNING: if this update is stopped early, it won't make a report ($($_.Exception.Message))" }
    exit 0
}

$report = Get-ReportPath
$Cancelled = $false
if ($Watch) {
    $lock = Join-Path $DataDir 'running.lock'
    $stateFile = Join-Path $DataDir 'state.txt'
    $parent = if ($ParentPid) { Get-Process -Id $ParentPid -ErrorAction SilentlyContinue } else { $null }
    function Test-Running {
        if ($parent -and $parent.HasExited) { return $false }
        # Update-Tool has the lock open for writing, so it can't be opened here without sharing
        try { $f = [IO.File]::Open($lock, 'Open', 'ReadWrite', 'None'); $f.Close(); return $false }
        catch [IO.FileNotFoundException], [IO.DirectoryNotFoundException] { return $false }
        catch { return $true }
    }
    # wait for the run to start (it writes its first step with the lock already open); probing the lock
    # any sooner could stop Update-Tool opening it
    $deadline = (Get-Date).AddMinutes(2)
    while (-not (Test-Path -LiteralPath $stateFile)) {
        if ((Get-Date) -gt $deadline -or ($parent -and $parent.HasExited)) { exit 0 }
        Start-Sleep -Milliseconds 500
    }
    # (no lock: Update-Tool couldn't make it, and runs without this)
    if (-not (Test-Path -LiteralPath $lock)) { exit 0 }
    while (Test-Running) {
        # a run that finishes makes the report while it still has the lock
        if (Test-Path -LiteralPath $report) { exit 0 }
        Start-Sleep -Milliseconds 500
    }
    Start-Sleep -Seconds 2
    if (Test-Path -LiteralPath $report) { exit 0 }
    $Cancelled = $true
}

# ---------------------------------------------------------------------------------------------
# The run's details
# ---------------------------------------------------------------------------------------------

# the text files Update-Tool.cmd writes, in the console's code page (as cmd writes them)
function Read-Lines([string]$path) {
    if (-not (Test-Path -LiteralPath $path)) { return @() }
    $encoding = try { [Console]::OutputEncoding } catch { [Text.Encoding]::Default }
    return @([IO.File]::ReadAllLines($path, $encoding) | Where-Object { $_.Trim() })
}

$finished = Get-Date
$startFile = Join-Path $DataDir 'start.json'
$start = if (Test-Path -LiteralPath $startFile) { Get-Content -LiteralPath $startFile -Raw | ConvertFrom-Json } else { $null }
$started = if ($start) { [DateTime]::Parse($start.started) } else { $finished }

# how far the run got (the last line for each key counts), and the apps started (start=<n>*<name>, one per app,
# from _Update-Apps.ps1, which updates several at once)
$state = @{}
$startedApps = @()
foreach ($line in Read-Lines (Join-Path $DataDir 'state.txt')) {
    $key, $value = $line -split '=', 2
    if ($null -eq $value) { continue }
    if ($key.Trim() -eq 'start') { $startedApps += ($value -split '\*', 2)[-1].Trim() } else { $state[$key.Trim()] = $value.Trim() }
}
$stepKind, $stepNumber, $stepApp = "$($state.step)" -split '\*', 3
if ($Cancelled) {
    # (what Update-Tool passes at the end, from what it had written so far)
    if ($start -and $start.doApps) { $DoApps = $start.doApps }
    if ($start -and $start.doScripts) { $DoScripts = $start.doScripts }
    $Scripts = if ($state.scripts) { $state.scripts } elseif ($DoScripts -eq '1') { 'cancelled' } else { 'skipped' }
    $SelfUpdate = if ($state.selfUpdate) { $state.selfUpdate } else { '0' }
    $Stamp = if ($state.stamp) { $state.stamp } else { '' }
}
# the apps were stopped with Ctrl+C, and Update-Tool was then told to carry on (N), so it finished up
# (what was stopped is the apps, not the steps after them)
if ($state.stopped -eq '1') { $Cancelled = $true; $stepKind = 'apps' }

$parts = @()
$resultsFile = Join-Path $DataDir 'results.jsonl'
if (Test-Path -LiteralPath $resultsFile) {
    $parts = @(Get-Content -LiteralPath $resultsFile -Encoding UTF8 | Where-Object { $_.Trim() } | ForEach-Object {
        try { $_ | ConvertFrom-Json } catch { }
    })
}

# each app folder Update-Tool tried, in its order, with update.cmd's exit code
$apps = @()
foreach ($line in Read-Lines (Join-Path $DataDir 'apps.txt')) {
    $code, $name = $line -split '\*', 2
    if (-not $name) { continue }
    $name = $name.Trim()
    $own = @($parts | Where-Object { $_.app -eq $name })
    $status = switch ($code.Trim()) {
        'skip' { 'skipped' }
        '0' { if ($own | Where-Object { $_.status -eq 'updated' }) { 'updated' } else { 'current' } }
        '2' { 'manual' }
        '3' { 'blocked' }
        # (stopped with Ctrl+C, then carried on with the next app)
        default { if ($own | Where-Object { $_.status -eq 'cancelled' }) { 'cancelled' } else { 'failed' } }
    }
    $apps += [pscustomobject]@{ Name = $name; Code = $code.Trim(); Status = $status; Parts = $own; Folder = (Join-Path $appsDir $name) }
}
# stopped early: the apps it was on, then the apps it never got to
$plan = @(Read-Lines (Join-Path $DataDir 'plan.txt') | ForEach-Object { $_.Trim() })
$interrupted = @()
$notTried = @()
if ($Cancelled) {
    # (stopped before it got to the apps: the app folders, as Update-Tool lists them)
    if (-not $plan -and $DoApps -eq '1' -and (Test-Path -LiteralPath $appsDir)) {
        $plan = @(Get-ChildItem -LiteralPath $appsDir -Directory | Where-Object { $_.Name -notlike '_*' } | ForEach-Object { $_.Name })
    }
    # the apps being updated (several at once; an older Update-Tool.cmd did one at a time, as step=app*<n>*<name>)
    $wereRunning = if ($stepKind -eq 'apps') { $startedApps } elseif ($stepKind -eq 'app' -and $stepApp) { @($stepApp) } else { @() }
    foreach ($name in $wereRunning) {
        if ($apps | Where-Object { $_.Name -eq $name }) { continue }
        $interrupted += $name
        $apps += [pscustomobject]@{ Name = $name; Code = ''; Status = 'cancelled'; Parts = @($parts | Where-Object { $_.app -eq $name }); Folder = (Join-Path $appsDir $name) }
    }
    foreach ($name in $plan) {
        if ($apps | Where-Object { $_.Name -eq $name }) { continue }
        $notTried += $name
        $apps += [pscustomobject]@{ Name = $name; Code = ''; Status = 'notrun'; Parts = @(); Folder = (Join-Path $appsDir $name) }
    }
}
# (parts from apps Update-Tool didn't list, eg. when this is run after a single app's update.cmd)
foreach ($group in $parts | Group-Object app) {
    if ($apps | Where-Object { $_.Name -eq $group.Name }) { continue }
    $worst = foreach ($s in 'failed', 'cancelled', 'manual', 'blocked', 'updated', 'current') { if ($group.Group | Where-Object { $_.status -eq $s }) { $s; break } }
    $apps += [pscustomobject]@{ Name = $group.Name; Code = ''; Status = $worst; Parts = @($group.Group); Folder = $group.Group[0].appFolder }
}
# in the order they were planned (several are updated at once, so they finish in any order)
if ($plan) {
    $order = @{}; for ($i = 0; $i -lt $plan.Count; $i++) { $order[$plan[$i]] = $i }
    $apps = @($apps | Sort-Object { if ($order.ContainsKey($_.Name)) { $order[$_.Name] } else { [int]::MaxValue } })
}

function Count($status) { @($apps | Where-Object { $_.Status -eq $status }).Count }
$counts = @{}
foreach ($s in 'updated', 'current', 'manual', 'failed', 'blocked', 'skipped', 'cancelled', 'notrun') { $counts[$s] = Count $s }

# where it stopped, eg. "while updating Blender (app 12 of 40)"
$stoppedAt = ''
if ($Cancelled) {
    $stoppedAt = switch ($stepKind) {
        'scripts' { 'while updating the scripts from GitHub' }
        'app' { "while updating $stepApp (app $stepNumber of $([Math]::Max($plan.Count, [int]$stepNumber)))" }
        'apps' {
            $finishedCount = @($apps | Where-Object { $_.Status -notin @('cancelled', 'notrun') }).Count
            $names = if ($interrupted.Count -gt 3) { ($interrupted[0..2] -join ', ') + " and $($interrupted.Count - 3) more" }
                elseif ($interrupted.Count -gt 1) { ($interrupted[0..($interrupted.Count - 2)] -join ', ') + " and $($interrupted[-1])" }
                else { "$interrupted" }
            "while updating the apps ($finishedCount of $($plan.Count) done$(if ($names) { "; $names $(if ($interrupted.Count -eq 1) { 'was' } else { 'were' }) still updating" }))"
        }
        'finish' { 'after trying every app, while finishing up' }
        'report' { 'while making this report' }
        default { 'as it started' }
    }
}
$downloaded = ($parts | Measure-Object -Property downloaded -Sum).Sum
$freeNow = Get-Free $Root

# ---------------------------------------------------------------------------------------------
# HTML helpers
# ---------------------------------------------------------------------------------------------

# (not called H: PowerShell's own h alias, for Get-History, would win over a function of that name)
function Enc([string]$text) { [Net.WebUtility]::HtmlEncode($text) }
function Size($bytes) {
    if ($null -eq $bytes) { return '?' }
    if ($bytes -ge 1GB) { return '{0:N1} GB' -f ($bytes / 1GB) }
    if ($bytes -ge 1MB) { return '{0:N0} MB' -f ($bytes / 1MB) }
    return '{0:N0} KB' -f ($bytes / 1KB)
}
function Span([TimeSpan]$t) {
    if ($t.TotalHours -ge 1) { return '{0} h {1} min' -f [int][Math]::Floor($t.TotalHours), $t.Minutes }
    if ($t.TotalMinutes -ge 1) { return '{0} min {1} s' -f [int][Math]::Floor($t.TotalMinutes), $t.Seconds }
    return '{0} s' -f [int]$t.TotalSeconds
}
function FileUrl([string]$path) { try { ([Uri]$path).AbsoluteUri } catch { '' } }
function Version($v, $built) {
    if ($v) { $text = Enc $v; if ($built) { $text += " <span class=`"dim`">($(Enc $built))</span>" }; return $text }
    if ($built) { return "<span class=`"dim`">dated $(Enc $built)</span>" }
    return '<span class="dim">&ndash;</span>'
}
# a path to run or open, with a copy button (browsers can't start scripts, so it's pasted into Win+R)
function RunBox([string]$label, [string]$path, [string]$hint = 'Copy, then press Win+R, paste and press Enter') {
    @"
<div class="run"><div class="run-label">$(Enc $label)</div><div class="run-row"><code>$(Enc $path)</code><button type="button" class="copy" data-copy="$(Enc $path)">Copy</button></div><div class="dim small">$(Enc $hint)</div></div>
"@
}
# an app's update log (the apps are updated several at once, so each one's output is in its own log, named
# "<n> <name>.log" for its place in plan.txt), without curl's progress bars, and only its last lines
function Get-AppLog([string]$name) {
    $index = [Array]::IndexOf($plan, $name)
    if ($index -lt 0) { return '' }
    $file = Get-ChildItem -LiteralPath (Join-Path $DataDir 'logs') -Filter ('{0:D3} *.log' -f ($index + 1)) -File -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $file) { return '' }
    $encoding = try { [Console]::OutputEncoding } catch { [Text.Encoding]::Default }
    $lines = [IO.File]::ReadAllText($file.FullName, $encoding) -split "`r`n|`n|`r" |
        Where-Object { $_.Trim() -and $_ -notmatch '^[#\s.%0-9]*$' -and $_ -notmatch '^-{20,}$' }
    return (@($lines) | Select-Object -Last 40) -join "`n"
}
$badgeText = @{ updated = 'Updated'; current = 'Up to date'; manual = 'Update by hand'; failed = 'Failed'; blocked = 'Defender blocked files'; skipped = 'No update.cmd'
    cancelled = 'Stopped part-way'; notrun = 'Not tried' }
function Badge([string]$status) { "<span class=`"badge $status`">$(Enc $badgeText[$status])</span>" }

# ---------------------------------------------------------------------------------------------
# What needs doing by hand
# ---------------------------------------------------------------------------------------------

$attention = New-Object Text.StringBuilder
if ($Cancelled) {
    # first: finishing the update
    [void]$attention.Append("<article class=`"card stop`"><header><h3>Finish the update</h3><span class=`"badge cancelled`">Cancelled</span></header>")
    [void]$attention.Append("<p>The update was stopped $(Enc $stoppedAt), at $(Enc $finished.ToString('h:mm tt')).</p>")
    if ($notTried) {
        [void]$attention.Append("<p>$(if ($notTried.Count -eq 1) { "1 app wasn't tried, so it's as it was" } else { "$($notTried.Count) apps weren't tried, so they're as they were" }): <span class=`"files`">$(($notTried | ForEach-Object { "<code>$(Enc $_)</code>" }) -join ' ')</span></p>")
    }
    if ($Scripts -eq 'cancelled') { [void]$attention.Append('<p>The scripts were stopped part-way through updating, so the drive may have a mix of old and new scripts.</p>') }
    # run it again: just the apps once the scripts are done (/apps), or just the scripts for a /scripts run
    $again = if ($DoApps -ne '1') { ' /scripts' } elseif ($Scripts -in @('updated', 'skipped')) { ' /apps' } else { '' }
    $hint = if ($again -eq ' /apps') { "Copy, then press Win+R, paste and press Enter (/apps leaves out the scripts, $(if ($Scripts -eq 'updated') { 'which this run already updated' } else { 'as this run did' }); apps that are already up to date are quick)" }
        else { 'Copy, then press Win+R, paste and press Enter (apps that are already up to date are quick)' }
    [void]$attention.Append((RunBox 'Run the update again' "`"$($Root)Update-Tool.cmd`"$again" $hint))
    [void]$attention.Append("</article>")
}
foreach ($app in $apps | Where-Object { $_.Status -in @('failed', 'manual', 'blocked', 'cancelled') }) {
    $folderUrl = FileUrl $app.Folder
    $partsNeeding = @($app.Parts | Where-Object { $_.status -in @('failed', 'manual', 'blocked', 'cancelled') })
    $shownActions = @{}
    [void]$attention.Append("<article class=`"card $($app.Status)`"><header><h3>$(Enc $app.Name)</h3>$(Badge $app.Status)</header>")
    if (-not $partsNeeding -and $app.Status -eq 'cancelled') {
        # stopped before the helper started on a part, or between parts
        $done = @($app.Parts | Where-Object { $_.status -in @('updated', 'current') } | ForEach-Object { $_.part })
        # (its update was ended while replacing files if it left its in-progress note; the next update redoes it)
        $halfDone = Get-ChildItem -LiteralPath $app.Folder -Filter 'update-in-progress.txt' -File -Recurse -Depth 1 -ErrorAction SilentlyContinue | Select-Object -First 1
        [void]$attention.Append("<p>The update was stopped while this app was being updated$(if ($done) { " (after $(Enc ($done -join ', ')))" }).$(if ($halfDone) { ' It was replacing its files, so its folder may be half-updated; the next update redoes it.' }) Update it again to finish it.</p>")
        [void]$attention.Append((RunBox 'Update it again' (Join-Path $app.Folder 'update.cmd')))
    }
    elseif (-not $partsNeeding) {
        # update.cmd stopped before the helper could say why (eg. a broken script)
        [void]$attention.Append("<p>update.cmd ended with exit code $(Enc $app.Code) without saying why. Run it on its own to see what happened.</p>")
        [void]$attention.Append((RunBox 'Run its update again' (Join-Path $app.Folder 'update.cmd')))
    }
    foreach ($part in $partsNeeding) {
        [void]$attention.Append("<section class=`"part`">")
        if ($partsNeeding.Count -gt 1 -or $app.Parts.Count -gt 1) { [void]$attention.Append("<h4>$(Enc $part.part) $(Badge $part.status)</h4>") }
        switch ($part.status) {
            'failed' {
                [void]$attention.Append("<p class=`"error`">$(Enc $part.message)</p>")
                $kept = if ($part.partWay) { 'It failed part-way through, so check the app''s folder (the next run tries again).' }
                    elseif ($part.oldVersion -or $part.oldBuilt) { "The version already on the USB ($(Enc $(if ($part.oldVersion) { $part.oldVersion } else { "dated $($part.oldBuilt)" }))) was kept." }
                    else { 'Nothing was changed.' }
                [void]$attention.Append("<p>$kept</p><div class=`"actions`">")
                if ($part.source) { [void]$attention.Append("<a class=`"button primary`" href=`"$(Enc $part.source)`" target=`"_blank`" rel=`"noopener`">Download it by hand &#8599;</a>") }
                [void]$attention.Append("</div>")
                [void]$attention.Append((RunBox 'Or try its update again' (Join-Path $app.Folder 'update.cmd')))
            }
            'manual' {
                if ($part.latest) {
                    $have = if ($part.oldVersion) { "this USB has $(Enc $part.oldVersion)" } else { "it isn't on this USB yet" }
                    [void]$attention.Append("<p><strong>Latest release: $(Enc $part.latest)</strong>; $have.</p>")
                }
                if ($part.note) { [void]$attention.Append("<p>$(Enc $part.note)</p>") }
                # (shown once per app, eg. Aseprite's build.cmd makes both its Installer and Portable parts)
                if ($part.action -and -not $shownActions[$part.action]) {
                    $text = if ($part.actionText) { $part.actionText } else { "Run $($part.action)" }
                    [void]$attention.Append((RunBox $text (Join-Path $app.Folder $part.action)))
                    $shownActions[$part.action] = $true
                }
                [void]$attention.Append("<div class=`"actions`">")
                if ($part.source) { [void]$attention.Append("<a class=`"button $(if ($part.action) { '' } else { 'primary' })`" href=`"$(Enc $part.source)`" target=`"_blank`" rel=`"noopener`">$(if ($part.action) { 'How to get it' } else { 'Download it' }) &#8599;</a>") }
                [void]$attention.Append("</div>")
                $target = if ($part.type) { Join-Path $app.Folder $part.type } else { $app.Folder }
                [void]$attention.Append("<p class=`"dim small`">$(if ($part.action) { 'Or put' } else { 'Put' }) what you download in <code>$(Enc $target)</code> (x64 for 64-bit-only builds, x86 for anything that runs on 32-bit Windows).</p>")
            }
            'cancelled' {
                $what = if ($part.partWay) { 'It was stopped while replacing its files, so its folder may be half-updated. Its version record was cleared, so the next update redoes it.' }
                    elseif ($part.oldVersion -or $part.oldBuilt) { "It was stopped before anything on the USB changed, so the version already there ($(Enc $(if ($part.oldVersion) { $part.oldVersion } else { "dated $($part.oldBuilt)" }))) was kept." }
                    else { 'It was stopped before anything on the USB changed.' }
                [void]$attention.Append("<p>$what</p>")
                [void]$attention.Append((RunBox 'Update it again' (Join-Path $app.Folder 'update.cmd')))
            }
            'blocked' {
                $files = @($part.blocked)
                [void]$attention.Append("<p>The update finished, but Windows Defender stopped $($files.Count) file(s) being copied: <span class=`"files`">$(($files | ForEach-Object { "<code>$(Enc $_)</code>" }) -join ' ')</span></p>")
                [void]$attention.Append("<p>To keep them, add Defender exclusions for the app's folder and the download folder, then run its update again.</p>")
                [void]$attention.Append("<div class=`"actions`"><a class=`"button primary`" href=`"windowsdefender://threat/`">Open Windows Security</a></div>")
                [void]$attention.Append((RunBox 'App folder to exclude' $app.Folder 'Copy, then add it under Virus & threat protection settings > Exclusions'))
                if ($part.exclusion) { [void]$attention.Append((RunBox 'Download folder to exclude' $part.exclusion 'Copy, then add it under Virus & threat protection settings > Exclusions')) }
                [void]$attention.Append((RunBox 'Then update it again' (Join-Path $app.Folder 'update.cmd')))
            }
        }
        [void]$attention.Append("</section>")
    }
    $log = Get-AppLog $app.Name
    if ($log) { [void]$attention.Append("<details class=`"log`"><summary>What its update said</summary><pre>$(Enc $log)</pre></details>") }
    if ($folderUrl) { [void]$attention.Append("<p class=`"small`"><a href=`"$(Enc $folderUrl)`">Open the app's folder</a></p>") }
    [void]$attention.Append("</article>")
}

# ---------------------------------------------------------------------------------------------
# What was updated, and every app
# ---------------------------------------------------------------------------------------------

$updatedRows = New-Object Text.StringBuilder
foreach ($part in $parts | Where-Object { $_.status -in @('updated', 'blocked') }) {
    $from = if ($part.oldVersion -or $part.oldBuilt) { Version $part.oldVersion $part.oldBuilt } else { '<span class="dim">new</span>' }
    [void]$updatedRows.Append("<tr><td>$(Enc $part.app)</td><td>$(Enc $part.part)</td><td>$from</td><td>$(Version $part.version $part.built)</td><td class=`"num`">$(Size $part.downloaded)</td><td class=`"num`">$(Span ([TimeSpan]::FromSeconds([double]$part.seconds)))</td></tr>")
}

$allRows = New-Object Text.StringBuilder
foreach ($app in $apps) {
    if (-not $app.Parts) {
        [void]$allRows.Append("<tr data-status=`"$($app.Status)`"><td>$(Enc $app.Name)</td><td class=`"dim`">&ndash;</td><td>$(Badge $app.Status)</td><td class=`"dim`">&ndash;</td><td class=`"num dim`">&ndash;</td></tr>")
        continue
    }
    foreach ($part in $app.Parts) {
        [void]$allRows.Append("<tr data-status=`"$($part.status)`"><td>$(Enc $app.Name)</td><td>$(Enc $(if ($part.type) { $part.type } else { $part.part }))</td><td>$(Badge $part.status)</td><td>$(Version $part.version $part.built)</td><td class=`"num`">$(Span ([TimeSpan]::FromSeconds([double]$part.seconds)))</td></tr>")
    }
}

# ---------------------------------------------------------------------------------------------
# The page
# ---------------------------------------------------------------------------------------------

$needYou = $counts.manual + $counts.failed
$needing = $needYou + $counts.blocked + $counts.cancelled
$needText = '{0} app{1} need{2} you' -f $needing, $(if ($needing -eq 1) { '' } else { 's' }), $(if ($needing -eq 1) { 's' } else { '' })
$headline = if ($Cancelled) { "Update cancelled $stoppedAt" }
    elseif ($DoApps -ne '1') { 'Scripts updated; apps were skipped' }
    elseif ($needing -eq 0) { 'Everything is up to date' }
    else { $needText }
# (under a cancelled headline: what that left)
$subline = if ($Cancelled) {
    $bits = @()
    if ($counts.notrun) { $bits += $(if ($counts.notrun -eq 1) { "1 app wasn't tried" } else { "$($counts.notrun) apps weren't tried" }) }
    if ($needing) { $bits += $needText }
    $bits -join '; '
}
$tone = if ($Cancelled -or $counts.failed -gt 0 -or $counts.cancelled -gt 0) { 'bad' } elseif ($needing -gt 0) { 'warn' } else { 'good' }
$scriptsText = switch ($Scripts) {
    'updated' { 'Updated from GitHub' }
    'FAILED' { 'FAILED to update (the drive''s scripts were left as they were)' }
    'cancelled' { 'Stopped part-way through updating' }
    default { 'Skipped' }
}
if ($SelfUpdate -eq '1') { $scriptsText += $(if ($Cancelled) { '; the new Update-Tool.cmd wasn''t copied in, as that happens at the end' } else { '; Update-Tool.cmd updated itself' }) }
$freeText = if ($start -and $null -ne $start.free -and $null -ne $freeNow) { "$(Size $freeNow) free <span class=`"dim`">(was $(Size $start.free))</span>" } else { "$(Size $freeNow) free" }
$stampText = if ($Stamp) { Enc ($Stamp -replace '^v(\d{4}-\d{2}-\d{2})\.version$', '$1') } elseif ($Cancelled) { '<span class="dim">not changed, as the update didn''t finish</span>' } else { '<span class="dim">not changed</span>' }

function Tile($number, $label, $class = '') { "<div class=`"tile $class`"><div class=`"n`">$number</div><div class=`"l`">$(Enc $label)</div></div>" }
$tiles = (Tile $counts.updated 'Updated' 'good') + (Tile $counts.current 'Already up to date') + (Tile $needYou 'Need updating by hand' $(if ($needYou) { 'warn' })) +
    (Tile $counts.failed 'Of those, failed' $(if ($counts.failed) { 'bad' })) + (Tile $counts.blocked 'Defender blocked files' $(if ($counts.blocked) { 'warn' }))
if ($counts.cancelled) { $tiles += Tile $counts.cancelled 'Stopped part-way' 'bad' }
if ($Cancelled) { $tiles += Tile $counts.notrun 'Not tried (cancelled)' $(if ($counts.notrun) { 'warn' }) }
$tiles += (Tile $counts.skipped 'Skipped (no update.cmd)') + (Tile (Size $downloaded) 'Downloaded')

$attentionHtml = if ($attention.Length) { "<h2>Needs you</h2><div class=`"cards`">$($attention.ToString())</div>" }
    elseif ($DoApps -eq '1') { "<h2>Needs you</h2><p class=`"ok`">Nothing: every app updated or was already up to date.</p>" } else { '' }
$updatedHtml = if ($updatedRows.Length) {
    "<h2>Updated <span class=`"count`">$(@($parts | Where-Object { $_.status -in @('updated', 'blocked') }).Count)</span></h2><div class=`"table-wrap`"><table><thead><tr><th>App</th><th>Part</th><th>Was</th><th>Now</th><th class=`"num`">Downloaded</th><th class=`"num`">Took</th></tr></thead><tbody>$($updatedRows.ToString())</tbody></table></div>"
} else { '' }
# a filter for each result in the table
$filterNames = [ordered]@{ updated = 'Updated'; current = 'Up to date'; manual = 'By hand'; failed = 'Failed'; blocked = 'Blocked'; cancelled = 'Stopped'; notrun = 'Not tried'; skipped = 'Skipped' }
$shown = $allRows.ToString()
$filterButtons = ($filterNames.Keys | Where-Object { $shown.Contains("data-status=`"$_`"") } | ForEach-Object { "<button type=`"button`" class=`"filter`" data-filter=`"$_`">$($filterNames[$_])</button>" }) -join ''
$allHtml = if ($allRows.Length) {
    @"
<h2>All apps <span class="count">$($apps.Count)</span></h2>
<div class="filters" role="group" aria-label="Show">
<button type="button" class="filter on" data-filter="">All</button>$filterButtons
<input type="search" id="find" placeholder="Find an app" aria-label="Find an app">
</div>
<div class="table-wrap"><table id="all"><thead><tr><th>App</th><th>Part</th><th>Result</th><th>Version on the USB</th><th class="num">Took</th></tr></thead><tbody>$($allRows.ToString())</tbody></table></div>
"@
} else { '' }

$html = @"
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>USB Tool Update Report</title>
<style>
:root { --bg: #f6f7f9; --panel: #ffffff; --text: #1d2330; --dim: #5d6675; --line: #dde1e7; --accent: #2457c5;
  --good: #1f7a3d; --good-bg: #e5f4ea; --warn: #8a5a00; --warn-bg: #fdf1d8; --bad: #b3261e; --bad-bg: #fbe5e3; --code: #eef1f5; }
@media (prefers-color-scheme: dark) { :root { --bg: #14171c; --panel: #1d2128; --text: #e6e9ee; --dim: #9aa3b0; --line: #313742; --accent: #7aa2ff;
  --good: #6fd08f; --good-bg: #17301f; --warn: #f0c060; --warn-bg: #362a12; --bad: #ff8a80; --bad-bg: #3a1a18; --code: #262b34; } }
* { box-sizing: border-box; }
body { margin: 0; background: var(--bg); color: var(--text); font: 15px/1.5 "Segoe UI", system-ui, sans-serif; }
main { max-width: 1100px; margin: 0 auto; padding: 24px 16px 48px; }
h1 { font-size: 26px; margin: 0 0 4px; } h2 { font-size: 19px; margin: 32px 0 12px; } h3 { font-size: 17px; margin: 0; } h4 { font-size: 15px; margin: 0 0 6px; }
.meta { color: var(--dim); margin: 0 0 16px; overflow-wrap: anywhere; }
p { overflow-wrap: anywhere; }
.banner { border-radius: 10px; padding: 14px 18px; font-size: 18px; font-weight: 600; margin: 16px 0; }
.banner.good { background: var(--good-bg); color: var(--good); } .banner.warn { background: var(--warn-bg); color: var(--warn); } .banner.bad { background: var(--bad-bg); color: var(--bad); }
.tiles { display: grid; grid-template-columns: repeat(auto-fit, minmax(140px, 1fr)); gap: 10px; }
.tile { background: var(--panel); border: 1px solid var(--line); border-radius: 10px; padding: 12px 14px; }
.tile .n { font-size: 26px; font-weight: 700; } .tile .l { color: var(--dim); font-size: 13px; }
.tile.good .n { color: var(--good); } .tile.warn .n { color: var(--warn); } .tile.bad .n { color: var(--bad); }
.facts { display: grid; grid-template-columns: max-content 1fr; gap: 4px 16px; margin: 16px 0 0; background: var(--panel); border: 1px solid var(--line); border-radius: 10px; padding: 12px 16px; }
.facts dt { color: var(--dim); } .facts dd { margin: 0; overflow-wrap: anywhere; }
.cards { display: grid; grid-template-columns: minmax(0, 1fr); gap: 12px; }
.card { background: var(--panel); border: 1px solid var(--line); border-left: 4px solid var(--warn); border-radius: 10px; padding: 14px 16px; }
.card.failed, .card.cancelled, .card.stop { border-left-color: var(--bad); }
.banner .sub { font-size: 15px; font-weight: 400; margin-top: 2px; }
.card header { display: flex; flex-wrap: wrap; align-items: center; gap: 8px; margin-bottom: 8px; }
.part + .part { border-top: 1px solid var(--line); margin-top: 12px; padding-top: 12px; }
.card p { margin: 6px 0; }
.error { color: var(--bad); overflow-wrap: anywhere; }
.badge { display: inline-block; font-size: 12px; font-weight: 600; padding: 1px 8px; border-radius: 999px; background: var(--code); color: var(--dim); white-space: nowrap; }
.badge.updated { background: var(--good-bg); color: var(--good); } .badge.manual, .badge.blocked { background: var(--warn-bg); color: var(--warn); } .badge.failed, .badge.cancelled { background: var(--bad-bg); color: var(--bad); }
.actions { display: flex; flex-wrap: wrap; gap: 8px; margin: 10px 0; } .actions:empty { display: none; }
.button { display: inline-block; padding: 7px 14px; border-radius: 8px; border: 1px solid var(--line); color: var(--text); text-decoration: none; font-weight: 600; background: var(--panel); }
.button.primary { background: var(--accent); border-color: var(--accent); color: #fff; }
@media (prefers-color-scheme: dark) { .button.primary { color: #0b1020; } }
.run { margin: 10px 0; } .run-label { font-weight: 600; margin-bottom: 4px; }
.run-row { display: flex; gap: 8px; align-items: stretch; }
.run-row code { flex: 1; min-width: 0; padding: 7px 10px; overflow-wrap: anywhere; }
code { background: var(--code); border-radius: 6px; padding: 1px 6px; font: 13px Consolas, "Cascadia Mono", monospace; overflow-wrap: anywhere; }
.files code { display: inline-block; margin: 2px 2px 0 0; }
details.log { margin: 10px 0 4px; } details.log summary { cursor: pointer; color: var(--dim); font-size: 13px; }
details.log pre { background: var(--code); border-radius: 8px; padding: 10px 12px; margin: 6px 0 0; font: 12px/1.45 Consolas, "Cascadia Mono", monospace; white-space: pre-wrap; overflow-wrap: anywhere; max-height: 320px; overflow-y: auto; }
button { font: inherit; cursor: pointer; }
.copy { padding: 0 14px; border-radius: 8px; border: 1px solid var(--line); background: var(--panel); color: var(--text); font-weight: 600; }
.copy.done { color: var(--good); }
.dim { color: var(--dim); } .small { font-size: 13px; } .ok { color: var(--good); font-weight: 600; }
.count { color: var(--dim); font-weight: 400; font-size: 15px; }
a { color: var(--accent); }
.table-wrap { overflow-x: auto; background: var(--panel); border: 1px solid var(--line); border-radius: 10px; }
table { border-collapse: collapse; width: 100%; font-size: 14px; }
th, td { text-align: left; padding: 7px 12px; border-bottom: 1px solid var(--line); vertical-align: top; }
th { color: var(--dim); font-weight: 600; position: sticky; top: 0; background: var(--panel); } tr:last-child td { border-bottom: 0; }
.num { text-align: right; white-space: nowrap; }
.filters { display: flex; flex-wrap: wrap; gap: 6px; margin-bottom: 10px; align-items: center; }
.filter { padding: 4px 12px; border-radius: 999px; border: 1px solid var(--line); background: var(--panel); color: var(--text); }
.filter.on { background: var(--accent); border-color: var(--accent); color: #fff; }
@media (prefers-color-scheme: dark) { .filter.on { color: #0b1020; } }
#find { margin-left: auto; padding: 5px 10px; border-radius: 8px; border: 1px solid var(--line); background: var(--panel); color: var(--text); font: inherit; min-width: 180px; }
@media (max-width: 600px) { .facts { grid-template-columns: 1fr; } .facts dd { margin-bottom: 6px; } #find { margin-left: 0; width: 100%; } }
</style>
</head>
<body>
<main>
<h1>USB Tool update</h1>
<p class="meta">$(Enc $Root) &middot; $(Enc $finished.ToString('dddd d MMMM yyyy, h:mm tt')) &middot; took $(Span ($finished - $started))</p>
<div class="banner $tone">$(Enc $headline)$(if ($subline) { "<div class=`"sub`">$(Enc $subline)</div>" })</div>
$(if ($DoApps -eq '1') { "<div class=`"tiles`">$tiles</div>" })
<dl class="facts">
<dt>Scripts</dt><dd>$(Enc $scriptsText)</dd>
<dt>Drive</dt><dd>$(Enc $Root) &middot; $freeText</dd>
<dt>Last updated</dt><dd>$stampText</dd>
<dt>Started</dt><dd>$(Enc $started.ToString('h:mm:ss tt'))</dd>
$(if ($Cancelled) { "<dt>Cancelled</dt><dd>$(Enc $finished.ToString('h:mm:ss tt')), $(Enc $stoppedAt)</dd>" } else { "<dt>Finished</dt><dd>$(Enc $finished.ToString('h:mm:ss tt'))</dd>" })
</dl>
$attentionHtml
$updatedHtml
$allHtml
<p class="dim small">Made by Update-Tool.cmd. Saved as $(Enc $report)$(if ($OutDir) { '; each update makes its own report next to this one.' } else { ', and replaced by the next update.' })</p>
</main>
<script>
document.addEventListener('click', function (e) {
  var b = e.target.closest('.copy');
  if (!b) return;
  var text = b.getAttribute('data-copy');
  function done() { b.textContent = 'Copied'; b.classList.add('done'); setTimeout(function () { b.textContent = 'Copy'; b.classList.remove('done'); }, 1500); }
  function fallback() { var t = document.createElement('textarea'); t.value = text; document.body.appendChild(t); t.select(); try { document.execCommand('copy'); done(); } catch (x) {} document.body.removeChild(t); }
  if (navigator.clipboard && navigator.clipboard.writeText) navigator.clipboard.writeText(text).then(done, fallback); else fallback();
});
var filter = '', rows = document.querySelectorAll('#all tbody tr'), find = document.getElementById('find');
function apply() {
  var q = find ? find.value.toLowerCase() : '';
  rows.forEach(function (r) { r.hidden = (filter && r.getAttribute('data-status') !== filter) || (q && r.cells[0].textContent.toLowerCase().indexOf(q) < 0); });
}
document.querySelectorAll('.filter').forEach(function (b) {
  b.addEventListener('click', function () { document.querySelectorAll('.filter').forEach(function (x) { x.classList.remove('on'); }); b.classList.add('on'); filter = b.getAttribute('data-filter'); apply(); });
});
if (find) find.addEventListener('input', apply);
</script>
</body>
</html>
"@

if ($OutDir) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }
[IO.File]::WriteAllText($report, $html, (New-Object Text.UTF8Encoding $false))
# (for Update-Tool.cmd to open; in the console's code page, which is how cmd reads it)
$encoding = try { [Console]::OutputEncoding } catch { [Text.Encoding]::Default }
# (no byte-order mark, which cmd would read as part of the path)
if ($encoding.CodePage -eq 65001) { $encoding = New-Object Text.UTF8Encoding $false }
[IO.File]::WriteAllText((Join-Path $DataDir 'report.txt'), $report, $encoding)
Write-Host "Report: $report"
# (the watcher opens it itself, as Update-Tool was stopped before it could)
if ($Watch) { Start-Process -FilePath $report }
