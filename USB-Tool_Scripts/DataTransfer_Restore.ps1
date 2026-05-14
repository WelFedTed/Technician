# work in progress (do not use yet)

# Data Transfer - Restore Script
# --------------------------------------------------
# This script will attempt to import / restore from
# data exported using the 'Data Transfer - Backup Script'

$directory = $args[0]
$logFile = "_restore.log"

function Log {
    param (
        [string]$message
    )
    New-Item -ItemType File -Path $logFile -ErrorAction SilentlyContinue | Out-Null
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "$timestamp - $message"
    Write-Output $logEntry | Out-File -FilePath $logFile -Append
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
# Check User
# ============================================================================
#  -->> UPDATE BACKUP SCRIPT TO ONLY GRAB 'PUBLIC' and current user directories, and skip AppData, ntuser.dat, etc..
# Check the backup's 'user' directory for number of users backed up, if more than 1, ask which user to restore
#   -> warn the user that if the user account folder name doesn't match, and if they proceed anyway, create symlink junction to new user folder name from old user folder name (this can fix migrated apps like Outlook looking for data files)


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


# ============================================================================
# Passwords
# ============================================================================


# ============================================================================
# Licenses
# ============================================================================


# ============================================================================
# Mail Clients
# ============================================================================


# ============================================================================
# Networking
# ============================================================================


# ============================================================================
# Devices
# ============================================================================
.\bin\rclone.exe copy printers C:\COPS\printers --progress --log-file=_rclone.log
#   -> create 'Install Printer XXX' shortcuts on Public user's Desktop

# ============================================================================
# Web Browsers
# ============================================================================


# ============================================================================
# Installed Programs
# ============================================================================
# fix winget if required (check this at beginnging of script, as it may cause script to crash)
# attempt to import winget.json
winget import winget.json
# check 'winget list' against winget.json and make list of apps that didnt install ($missingApps)
# check winget_unavailable.txt and update $missingApps
# check other 'installed programs' exports and update $missingApps
# Present list of $missingApps to user at end of script (part of TODO Report)

# ============================================================================
# Security Software
# ============================================================================


# ============================================================================
# Recent Documents
# ============================================================================
Get-ChildItem -Path ".\recent-documents" -Filter "*.reg" -File | ForEach-Object {
    Write-Host "Importing $($_.FullName)..."
    reg import "$($_.FullName)"
}

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
write-Output "Done"
Log "Done"
Write-Output ""

# ============================================================================
# Fonts
# ============================================================================
$fontFolder   = "fonts"
$fontsRegPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
$windowsFonts = Join-Path $env:WINDIR "Fonts"

Get-ChildItem $fontFolder -Recurse -Include *.ttf, *.otf, *.ttc, *.fon | ForEach-Object {
    $source      = $_.FullName
    $fontFile    = $_.Name
    $destination = Join-Path $windowsFonts $fontFile

    if (Test-Path $destination) {
        Write-Host "Skipping already installed font: $fontFile"
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

    Write-Host "Installed: $fontFile"
}

# ============================================================================
# Drivers
# ============================================================================
$DriverFolder = "drivers"

if (-not (Test-Path $DriverFolder)) {
    Write-Host "Drivers folder not found." -ForegroundColor Red
    exit 1
}

$MissingDevices = Get-PnpDevice -Status Error |
Where-Object { $_.Problem -eq 28 }

if (-not $MissingDevices) {
    Write-Host "No missing drivers found." -ForegroundColor Green
    exit 0
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


# ============================================================================
# Registry Hives
# ============================================================================
.\bin\rclone.exe copy "registry" "C:\COPS\old-registry-backup" --progress --log-file=_rclone.log

# ============================================================================
# Other C: Drive Directories
# ============================================================================
.\bin\rclone.exe copy "c" "C:\" --progress --log-file=_rclone.log

# ============================================================================
# OneDrive
# ============================================================================
# Check if active onedrive folder is empty
#   -> if empty, proceed
#   -> if not empty, warn user (dont migrate onedrive data at this point?)


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
# Create a _restore_todos.txt and open at end of script for list of to-do's / calls to action for technician

Write-Output "Restore Complete"
Log "----------------------------------------"
Log "Restore Complete"
Log "----------------------------------------"
Write-Output ""

cmd /k pause
exit
