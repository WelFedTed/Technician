# Data Transfer - Backup Script
# --------------------------------------------------
# This script will use a variety of tools to export
# a PC's user data and configurations to the current
# working directory.
# This export / backup can then be used to restore
# on to aother device.

$directory=$args[0]
$logFile = "_backup.log"

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

Write-Output "Data Transfer - Backup Script"
Write-Output "----------------------------------------"
write-Output ""
Log "----------------------------------------"
Log "Starting Backup Script"
Log "----------------------------------------"

Write-Output "Exporting to: $directory"
Log "Exporting to: $directory"
Write-Output ""

Write-Output "Logging to file: $logFile"
Log "Logging to file: $logFile"
Write-Output ""

Write-Output "Downloading dependencies..."
Log "Downloading dependencies..."
Write-Output ""
New-Item -Path "bin" -ItemType Directory -ErrorAction SilentlyContinue | Out-Null
$headers = @{
    "Referer" = "http://www.example.com/previous-page.html"
}

$dependencies = @(
    # Name, URL (x86), URL (x64), Password
    @("7zip", "https://www.7-zip.org/a/7za920.zip", $null, $null),
    @("Nirsoft LostMyPassword", "https://www.nirsoft.net/utils/lostmypassword.zip", "https://www.nirsoft.net/utils/lostmypassword-x64.zip", $null),
    @("Nirsoft WebBrowserPassView", "https://www.nirsoft.net/toolsdownload/webbrowserpassview.zip", $null, "wbpv28821@"),
    @("Nirsoft WirelessKeyView", "https://www.nirsoft.net/toolsdownload/wirelesskeyview.zip", "https://www.nirsoft.net/toolsdownload/wirelesskeyview-x64.zip", "WKey4567#"),
    @("Rclone", "https://downloads.rclone.org/rclone-current-windows-386.zip", "https://downloads.rclone.org/rclone-current-windows-amd64.zip", $null)
)

foreach ($dep in $dependencies) {
    $name = $dep[0]
    $url = if ([Environment]::Is64BitOperatingSystem -and $dep[2]) { $dep[2] } else { $dep[1] }
    $password = $dep[3]

    $ProgressPreference = "SilentlyContinue"    # Hides progress bar, but speeds up downloads
    # $ProgressPreference = "Continue"            # Shows progress bar

    Write-Output "Downloading $name..."
    Log "Downloading $name..."
    $outputPath = "$env:TEMP\$($name -replace ' ', '')-download.zip"
    Invoke-WebRequest -Uri $url -OutFile $outputPath -Headers $headers

    if ($name -eq "7zip") {
        Expand-Archive -Path $outputPath -DestinationPath "bin" -Force
    } else {
        if ($password) {
            .\bin\7za.exe e $outputPath -o"bin" -p"$password" -y | Out-Null
        } else {
            .\bin\7za.exe e $outputPath -o"bin" -y | Out-Null
        }
    }

    Remove-Item -Path $outputPath -Force

    Write-Output "Done"
    Log "Done"
    Write-Output ""
}

Write-Output "Extracting Passwords..."
Log "Extracting Passwords..."
.\bin\LostMyPassword.exe /shtml "passwords_nirsoft-lostmypassword.html"
.\bin\WebBrowserPassView.exe /shtml "passwords_nirsoft-webbrowserpassview.html"
Write-Output "Done"
Log "Done"
Write-Output ""

Write-Output "Extracting Wireless Network Keys..."
Log "Extracting Wireless Network Keys..."
.\bin\WirelessKeyView.exe /export "wireless-networks_nirsoft-wirelesskeyview.txt"
Write-Output "Done"
Log "Done"
Write-Output ""

Write-Output "Backing up User Profiles..."
Log "Backing up User Profiles..."
.\bin\rclone.exe copy "C:\Users" "users" --progress
write-Output "Done"
Log "Done"
Write-Output ""

Write-Output "Backing up Fonts..."
Log "Backing up Fonts..."
.\bin\rclone.exe copy "C:\Windows\Fonts" "fonts" --progress
write-Output "Done"
Log "Done"
Write-Output ""

Write-Output "Exporting Drivers..."
Log "Exporting Drivers..."
New-Item -Path "drivers" -ItemType Directory -ErrorAction SilentlyContinue | Out-Null
Export-WindowsDriver -Online -Destination ".\drivers"
write-Output "Done"
Log "Done"
Write-Output ""


# replace this with a pause to keep the window open
Start-Sleep -Seconds 15