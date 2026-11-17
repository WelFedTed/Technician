# Run-Web - runs a script tool's latest version straight from the web, as the tool's own "irm <address> | iex"
# command does (eg. irm christitus.com/win | iex), falling back to the copy on the USB
# --------------------------------------------------
# Used by the launchers of tools that have such a command: with internet, the script at -Web is run; without
# internet, or when the address gives a web page instead of a script (eg. a Wi-Fi sign-in page), or when Windows
# blocks it (Defender scans scripts before they run), the copy on the USB is run instead:
#   - with -Local, this script runs that copy itself (a .ps1)
#   - without it, it exits with 10, and the launcher (made from _Run-Template.cmd, with its web setting) runs
#     its own copy, eg. an installer
#
#   -Web <url>          the address the tool's irm | iex command uses
#   -Name <text>        the tool's name, for messages
#   -Arguments <text>   passed to the script, as typed after it in a PowerShell window (eg. "/HWID" or "-UseMSI")
#   -Local <file>       the copy on the USB to run instead (a .ps1)
#   -Admin              run as admin: asks for it, then runs in a new window that stays open afterwards
#
# Exit codes: the script's own (0 if it doesn't set one), 1 = couldn't run it at all,
#             10 = couldn't get or run it from the web, and there's no -Local copy (the launcher's turn)

param(
    [Parameter(Mandatory = $true)][string]$Web,
    [string]$Name,
    [string]$Arguments,
    [string]$Local,
    [switch]$Admin,
    [switch]$Elevated
)

if (-not $Name) { $Name = 'This tool' }

# -Admin: start again as admin, in a new window that stays open (asking once, here)
if ($Admin -and -not $Elevated) {
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        # (each argument quoted, as Start-Process joins them with spaces)
        $list = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-NoExit', '-File', $PSCommandPath, '-Web', $Web, '-Name', $Name, '-Arguments', $Arguments, '-Local', $Local, '-Elevated') |
            ForEach-Object { '"' + ([string]$_).Replace('"', '\"') + '"' }
        try {
            Start-Process -FilePath "$PSHOME\powershell.exe" -Verb RunAs -ArgumentList ($list -join ' ') -ErrorAction Stop
            exit 0
        }
        catch {
            Write-Host "$Name needs to run as admin, and that was cancelled." -ForegroundColor Yellow
            exit 1
        }
    }
}
if ($Elevated) { $Host.UI.RawUI.WindowTitle = "$Name (Administrator)" }

# runs a script block (or a script file) with the arguments, as they'd be typed after it
function Invoke-Tool($tool) {
    $call = [scriptblock]::Create("param(`$tool) & `$tool $Arguments")
    & $call $tool
}

# --- the web
$code = $null
$why = ''
try {
    # (older Windows PowerShell only offers old TLS versions unless asked)
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    Write-Host "Getting the latest version from $Web ..."
    $got = Invoke-RestMethod -Uri $Web -UseBasicParsing -TimeoutSec 30 -ErrorAction Stop
    if ($got -is [byte[]]) { $got = [Text.Encoding]::UTF8.GetString($got) }
    if ($got -isnot [string] -or $got.Length -lt 100) { $why = "it didn't give a script" }
    elseif ($got.TrimStart() -match '^(<!doctype|<html)') { $why = 'it gave a web page instead of the script (a Wi-Fi sign-in page?)' }
    else { $code = $got }
}
catch { $why = "couldn't reach it ($($_.Exception.Message))" }

$tool = $null
if ($code) {
    try { $tool = [scriptblock]::Create($code) }
    catch {
        $why = if ($_.FullyQualifiedErrorId -match 'ScriptContainedMaliciousContent') { 'Windows blocked it (Defender flags it)' } else { "it didn't load ($($_.Exception.Message))" }
    }
}
if ($tool) {
    Write-Host "Running the latest version from the web..." -ForegroundColor Cyan
    Write-Host ''
    $global:LASTEXITCODE = 0
    try { Invoke-Tool $tool; exit $LASTEXITCODE }
    catch {
        # (Windows can also block it as it runs; anything else is the script's own error)
        if ($_.FullyQualifiedErrorId -notmatch 'ScriptContainedMaliciousContent') { throw }
        $why = 'Windows blocked it (Defender flags it)'
    }
}

# --- the copy on the USB
Write-Host "Couldn't run the latest version from the web: $why." -ForegroundColor Yellow
if (-not $Local) { exit 10 }
if (-not (Test-Path -LiteralPath $Local)) {
    Write-Host "There's no copy of it on the USB either ($Local)." -ForegroundColor Yellow
    Write-Host 'Run Update-Tool.cmd while online to save one.'
    exit 1
}
Write-Host "Running the copy on the USB instead ($(Split-Path -Leaf $Local), saved $((Get-Item -LiteralPath $Local).LastWriteTime.ToString('d MMM yyyy')))..." -ForegroundColor Cyan
Write-Host ''
$global:LASTEXITCODE = 0
Invoke-Tool $Local
exit $LASTEXITCODE