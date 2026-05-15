# Data Transfer - Restore Script
# --------------------------------------------------
# This script will attempt to import / restore from
# data exported using the 'Data Transfer - Backup Script'

$directory = $args[0]
$logFile = "_restore.log"
$todoFile = "_restore_todos.txt"

function Log {
    param (
        [string]$message
    )
    New-Item -ItemType File -Path $logFile -ErrorAction SilentlyContinue | Out-Null
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "$timestamp - $message"
    Write-Output $logEntry | Out-File -FilePath $logFile -Append
}

function Todo {
    param (
        [string]$message
    )
    New-Item -ItemType File -Path $todoFile -ErrorAction SilentlyContinue | Out-Null
    Write-Output "$message" | Out-File -FilePath $todoFile -Append
}

Set-Location -Path $directory

Write-Output "Data Transfer - Restore Script"
Write-Output "----------------------------------------"
write-Output ""
Log "----------------------------------------"
Log "Starting Restore Script"
Log "----------------------------------------"

# ============================================================================
# Set Power Settings
# ============================================================================
Write-Output "Setting power settings to prevent sleep on AC power..."
Log "Setting power settings to prevent sleep on AC power..."
powercfg /change standby-timeout-ac 0
powercfg /change monitor-timeout-ac 0
Write-Output "Done"
Log "Done"
Write-Output ""

# ============================================================================
# Close Non-Essential Apps
# ============================================================================
Write-Output "Closing non-essential applications..."
Log "Closing non-essential applications..."
Get-Process | Where-Object { $_.MainWindowTitle -ne "" -and $_.Id -ne $PID -and $_.ProcessName -ne "explorer" } | Stop-Process -Force
Write-Output "Done"
Log "Done"
Write-Output ""

# ============================================================================
# Disable Security
# ============================================================================
Write-Output "Disabling Windows Defender..."
Log "Disabling Windows Defender..."
Add-MpPreference -ExclusionPath $directory
Set-MpPreference -DisableRealtimeMonitoring $true
Set-MpPreference -DisableScriptScanning $true
Set-MpPreference -DisableBehaviorMonitoring $true
Set-MpPreference -DisableIOAVProtection $true
Set-MpPreference -DisableIntrusionPreventionSystem $true
Write-Output "Done"
Log "Done"
Write-Output ""

# ============================================================================
# Download Dependancies
# ============================================================================
Write-Output "Checking dependencies..."
Log "Checking dependencies..."
Write-Output ""
New-Item -Path "bin" -ItemType Directory -ErrorAction SilentlyContinue >> $logFile
$headers = @{
    "Referer" = "http://www.example.com/previous-page.html"
}

$dependencies = @(
    # Name, URL (x86), URL (x64), Password, Executable
    @("7zip", "https://www.7-zip.org/a/7za920.zip", $null, $null, "7za.exe"),
    @("Nirsoft WirelessKeyView", "https://www.nirsoft.net/toolsdownload/wirelesskeyview.zip", "https://www.nirsoft.net/toolsdownload/wirelesskeyview-x64.zip", "WKey4567#", "WirelessKeyView.exe"),
    @("Rclone", "https://downloads.rclone.org/rclone-current-windows-386.zip", "https://downloads.rclone.org/rclone-current-windows-amd64.zip", $null, "rclone.exe")
)

foreach ($dep in $dependencies) {
    $name = $dep[0]
    $url = if ([Environment]::Is64BitOperatingSystem -and $dep[2]) { $dep[2] } else { $dep[1] }
    $password = $dep[3]
    $exe = $dep[4]

    if (Test-Path -Path ".\bin\$exe") {
        Write-Output "$name already exists, skipping download."
        Log "$name already exists, skipping download."
        Write-Output ""
        continue
    }

    # $ProgressPreference = "SilentlyContinue"    # Hides progress bar, but speeds up downloads
    Write-Output "Downloading $name..."
    Log "Downloading $name..."
    New-Item -Path "temp" -ItemType Directory -ErrorAction SilentlyContinue >> $logFile
    $outputPath = "temp\$($name -replace ' ', '')-download.zip"
    Invoke-WebRequest -Uri $url -OutFile $outputPath -Headers $headers

    if ($name -eq "7zip") {
        Expand-Archive -Path $outputPath -DestinationPath "bin" -Force
    }
    else {
        if ($password) {
            .\bin\7za.exe e $outputPath -o"bin" -p"$password" -y >> $logFile
        }
        else {
            .\bin\7za.exe e $outputPath -o"bin" -y >> $logFile
        }
    }

    Remove-Item -Path $outputPath -Force

    Write-Output "Done"
    Log "Done"
    Write-Output ""
}

# ============================================================================
# AppData
# ============================================================================
Write-Output "Restoring AppData..."
Log "Restoring AppData..."

$appDataPaths = @(
    @{
        Path = "Local\AVG Software\Browser"
        Processes = @("AVGBrowser")
    },
    @{
        Path = "Local\BraveSoftware\Brave-Browser"
        Processes = @("brave")
    },
    @{
        Path = "Local\Chromium"
        Processes = @("chromium")
    },
    @{
        Path = "Local\Google\Chrome"
        Processes = @("chrome")
    },
    @{
        Path = "Local\Microsoft\Edge"
        Processes = @("msedge")
    },
    @{
        Path = "Local\Microsoft\Outlook"
        Processes = @("outlook")
    },
    @{
        Path = "Local\Vivaldi"
        Processes = @("vivaldi")
    },
    @{
        Path = "LocalLow\Sun\Java"
        Processes = @("java", "javaw")
    },
    @{
        Path = "Roaming\eM Client"
        Processes = @("MailClient")
    },
    @{
        Path = "Roaming\Mozilla\Firefox"
        Processes = @("firefox")
    },
    @{
        Path = "Roaming\Opera Software\Opera Stable"
        Processes = @("opera")
    },
    @{
        Path = "Roaming\Thunderbird"
        Processes = @("thunderbird")
    }
)

foreach ($item in $appDataPaths) {
    $appDataPath = $item.Path
    $targetPath  = "$env:USERPROFILE\AppData\$appDataPath"

    foreach ($process in $item.Processes) {
        $proc = Get-Process -Name $process -ErrorAction SilentlyContinue
        if ($proc) {
            Write-Output "Closing process: $process"
            Log "Closing process: $process"
            $proc | Stop-Process -Force
        }
    }

    # Wait briefly to ensure processes fully exit
    Start-Sleep -Seconds 2

    if (Test-Path $targetPath) {
        Rename-Item -Path $targetPath -NewName "$(Split-Path $targetPath -Leaf).old" -ErrorAction SilentlyContinue
        .\bin\rclone.exe copy ".\appdata\$appDataPath" $targetPath --progress --log-file=_rclone.log
        Write-Output "Restored AppData\$appDataPath"
        Log "Restored AppData\$appDataPath"
    }
}
Write-Output "Done"
Log "Done"
write-Output ""

# ============================================================================
# Desktop / System / Users
# ============================================================================
Write-Output "Restoring Desktop..."
Log "Restoring Desktop..."
    Todo "============================================================================"
    Todo "Desktop / System / Users"
    Todo "============================================================================"
    Todo "  Restore Wallpaper"
    Todo ""
Write-Output "Done"
Log "Done"
write-Output ""

# ============================================================================
# Passwords
# ============================================================================
Write-Output "Restoring Passwords..."
Log "Restoring Passwords..."
    Todo "============================================================================"
    Todo "Passwords"
    Todo "============================================================================"
    Todo "  Restore Network Passwords"
    Todo "  Restore Remote Desktop Passwords"
    Todo "  Restore VNC Passwords"
    Todo ""
Write-Output "Done"
Log "Done"
Write-Output ""

# ============================================================================
# Licenses
# ============================================================================
Write-Output "Restoring Licenses..."
Log "Restoring Licenses..."
    Todo "============================================================================"
    Todo "Licenses"
    Todo "============================================================================"
    Todo "  Restore Windows License as required"
    Todo "  Restore Microsoft Office License as required"
    Todo ""
Write-Output "Done"
Log "Done"
Write-Output ""

# ============================================================================
# Mail Clients
# ============================================================================
Write-Output "Restoring Mail Clients..."
Log "Restoring Mail Clients..."
reg import "outlook_profile_2007-2010.reg" >> $logFile
reg import "outlook_profile_2013.reg" >> $logFile
reg import "outlook_profile_2016-onwards.reg" >> $logFile
    Todo "============================================================================"
    Todo "Mail Clients"
    Todo "============================================================================"
    Todo "  Test Outlook (classic) migrated correctly (may require account passwords)"
    Todo "  Test Thunderbird migrated correctly"
    Todo "  Test eM Client migrated correctly"
    Todo "  Setup 'Outlook (new)' as required (will require contacts to be imported manually)"
    Todo "  Setup other mail clients as required"
    Todo ""
Write-Output "Done"
Log "Done"
Write-Output ""

# ============================================================================
# Networking
# ============================================================================
Write-Output "Restoring Networking..."
Log "Restoring Networking..."
.\bin\WirelessKeyView.exe /import "wireless-networks_nirsoft-wirelesskeyview.txt"
    Todo "============================================================================"
    Todo "Networking"
    Todo "============================================================================"
    Todo "  Restore Network Adapter Settings as required (static IP's, DNS settings, etc..)"
    Todo ""
Write-Output "Done"
Log "Done"
Write-Output ""

# ============================================================================
# Devices
# ============================================================================
Write-Output "Restoring Devices..."
Log "Restoring Devices..."
    Todo "============================================================================"
    Todo "Devices"
    Todo "============================================================================"
    Todo "  Create desktop shortcuts to Printer installers (i.e. 'Install Printer - Canon TS5100 Series', put them in the top right hand corner of the desktop if available"
    Todo "  Restore device HOSTNAME as required"
    Todo "  Restore Mapped Network Drives as required"
    Todo ""
.\bin\rclone.exe copy "printers" "C:\COPS\printers" --progress --log-file=_rclone.log
Write-Output "Done"
Log "Done"
Write-Output ""

# ============================================================================
# Web Browsers
# ============================================================================
Write-Output "Restoring Web Browsers..."
Log "Restoring Web Browsers..."
    Todo "============================================================================"
    Todo "Web Browsers"
    Todo "============================================================================"
    Todo "  Import Passwords in to all Web Browsers as per exports"
    Todo ""
Write-Output "Done"
Log "Done"
Write-Output ""

# ============================================================================
# Installed Programs
# ============================================================================
# fix winget if required? (check this at beginnging of script, as it may cause script to crash)
# attempt to import winget.json
# check 'winget list' against winget.json and make list of apps that didnt install ($missingApps)
# check winget_unavailable.txt and update $missingApps
# check other 'installed programs' exports and update $missingApps
# Present list of $missingApps to user at end of script (part of TODO Report)
Write-Output "Restoring Installed Programs..."
Log "Restoring Installed Programs..."
winget import winget.json --accept-source-agreements >> $logFile
winget install -e --id DucFabulous.UltraViewer      # we use this for remote access support
    Todo "============================================================================"
    Todo "Installed Programs"
    Todo "============================================================================"
    Todo "  Install missing programs"
    Todo ""
Write-Output "Done"
Log "Done"
Write-Output ""

# ============================================================================
# Security Software
# ============================================================================
Write-Output "Restoring Security Software..."
Log "Restoring Security Software..."
    Todo "============================================================================"
    Todo "Security Software"
    Todo "============================================================================"
    Todo "  Setup Security Software as required"
    Todo ""
Write-Output "Done"
Log "Done"
Write-Output ""

# ============================================================================
# Recent Documents
# ============================================================================
Write-Output "Restoring Recent Documents Lists..."
Log "Restoring Recent Documents Lists..."
Get-ChildItem -Path ".\recent-documents" -Filter "*.reg" -File | ForEach-Object {
    reg import "$($_.FullName)"
}
Write-Output "Done"
Log "Done"
Write-Output ""

# ============================================================================
# User Profiles
# ============================================================================
Write-Output "Restoring User Profiles..."
Log "Restoring User Profiles..."
.\bin\rclone.exe copy "users" "C:\Users" `
    --progress `
    --log-file=_rclone.log `
    --exclude "**/AppData/**" `
    --exclude "**/Dropbox/**" `
    --exclude "**/OneDrive/**" `
    --exclude "**/NTUSER*"

# create symlink if user's HOME directory is different
$expectedHome = (Get-Content ".\home-folder.txt" -Raw).Trim()
$expectedHome = $expectedHome.TrimEnd('\')
$currentHome = $HOME.TrimEnd('\')

if ($currentHome -ieq $expectedHome) {
    Write-Host "Current HOME path already matches: $currentHome"
    Log "Current HOME path already matches: $currentHome"
} elseif (Test-Path $expectedHome) {
    Write-Host "Expected HOME path already exists: $expectedHome"
    Log "Expected HOME path already exists: $expectedHome"
} else {
    # Create the parent directory if needed
    $parentDir = Split-Path $expectedHome -Parent
    if (-not (Test-Path $parentDir)) {
        New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
    }

    Write-Host "Creating HOME path junction:"
    Write-Host "`"$expectedHome`" -> `"$currentHome`""
    Log "Creating HOME path junction:"
    Log "`"$expectedHome`" -> `"$currentHome`""
    New-Item -ItemType Junction -Path $expectedHome -Target $currentHome
}
Write-Output "Done"
Log "Done"
Write-Output ""

# ============================================================================
# Fonts
# ============================================================================
Write-Output "Restoring Fonts..."
Log "Restoring Fonts..."
$fontFolder   = "fonts"
$fontsRegPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
$windowsFonts = Join-Path $env:WINDIR "Fonts"

Get-ChildItem $fontFolder -Recurse -Include *.ttf, *.otf, *.ttc, *.fon | ForEach-Object {
    $source      = $_.FullName
    $fontFile    = $_.Name
    $destination = Join-Path $windowsFonts $fontFile

    if (Test-Path $destination) {
        # Write-Host "Skipping already installed font: $fontFile"
        return
    }

    Copy-Item $source $destination

    switch ($_.Extension.ToLower()) {
        ".ttf" { $suffix = " (TrueType)" }
        ".otf" { $suffix = " (OpenType)" }
        ".ttc" { $suffix = " (TrueType)" }
        ".fon" { $suffix = "" }
        default { $suffix = "" }
    }

    New-ItemProperty `
        -Path $fontsRegPath `
        -Name ($_.BaseName + $suffix) `
        -Value $fontFile `
        -PropertyType String `
        -Force | Out-Null

    # Write-Host "Installed: $fontFile"
}
Write-Output "Done"
Log "Done"
Write-Output ""

# ============================================================================
# Drivers
# ============================================================================
Write-Output "Restoring Drivers..."
Log "Restoring Drivers..."

# install missing drivers
$DriverFolder = "drivers"

if (-not (Test-Path $DriverFolder)) {
    Write-Host "Drivers folder not found." -ForegroundColor Red
}

$MissingDevices = Get-PnpDevice -Status Error |
Where-Object { $_.Problem -eq 28 }

if (-not $MissingDevices) {
    Write-Host "No missing drivers found." -ForegroundColor Green
}

foreach ($Device in $MissingDevices) {
    Write-Host ""
    Write-Host "Searching driver for:" -ForegroundColor Cyan
    Write-Host "  $($Device.FriendlyName)"

    $HardwareIds = (
        Get-PnpDeviceProperty `
            -InstanceId $Device.InstanceId `
            -KeyName 'DEVPKEY_Device_HardwareIds'
    ).Data

    if (-not $HardwareIds) {
        Write-Host "  No hardware IDs found." -ForegroundColor Yellow
        continue
    }

    $MatchingInfs = Get-ChildItem $DriverFolder -Recurse -Filter *.inf |
    Where-Object {

        $Content = Get-Content $_.FullName -ErrorAction SilentlyContinue

        foreach ($HWID in $HardwareIds) {
            if ($Content -match [regex]::Escape($HWID)) {
                return $true
            }
        }

        return $false
    }

    if (-not $MatchingInfs) {
        Write-Host "  No matching drivers found." -ForegroundColor Yellow
        continue
    }

    foreach ($Inf in $MatchingInfs) {
        Write-Host "  Installing: $($Inf.Name)" -ForegroundColor Green

        pnputil /add-driver "$($Inf.FullName)" /install
    }
}

Write-Host ""
Write-Host "Rescanning devices..." -ForegroundColor Cyan

pnputil /scan-devices

# copy drivers backup
.\bin\rclone.exe copy "drivers" "C:\COPS\old-drivers-backup" --progress --log-file=_rclone.log
Write-Output "Done"
Log "Done"
Write-Output ""

# ============================================================================
# Registry Hives
# ============================================================================
Write-Output "Restoring Registry..."
Log "Restoring Registry..."
.\bin\rclone.exe copy "registry" "C:\COPS\old-registry-backup" --progress --log-file=_rclone.log
Write-Output "Done"
Log "Done"
Write-Output ""

# ============================================================================
# Other C: Drive Directories
# ============================================================================
Write-Output "Restoring Other C: Drive Directories..."
Log "Restoring Other C: Drive Directories..."
.\bin\rclone.exe copy "c" "C:\" --progress --log-file=_rclone.log
Write-Output "Done"
Log "Done"
Write-Output ""

# ============================================================================
# OneDrive
# ============================================================================
Write-Output "Restoring OneDrive..."
Log "Restoring OneDrive..."
    Todo "============================================================================"
    Todo "OneDrive"
    Todo "============================================================================"
    Todo "  If OneDrive is fully synced on old device:"
    Todo "      -> Log in to OneDrive and use same settings for folders (i.e. Desktop, Documents, Photos, etc..)"
    Todo ""
    Todo "  If OneDrive is NOT fully synced on old device:"
    Todo "      -> Merge backed up OneDrive data back in to User directory"
    Todo ""
Log "Done"
Write-Output ""

# ============================================================================
# Reset Power Settings
# ============================================================================
Write-Output "Resetting power settings..."
Log "Resetting power settings..."
powercfg /restoredefaultschemes >> $logFile
Write-Output "Done"
Log "Done"
Write-Output ""

# ============================================================================
# Report To-Do's
# ============================================================================
Write-Output "Reporting Outstanding To-Do's to complete Restore process..."
Log "Reporting Outstanding To-Do's to complete Restore process..."
start $todoFile
Write-Output "Done"
Log "Done"
Write-Output ""

Write-Output "Restore Complete"
Log "----------------------------------------"
Log "Restore Complete"
Log "----------------------------------------"
Write-Output ""

cmd /k pause
exit
