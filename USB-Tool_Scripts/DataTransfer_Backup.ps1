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
    @("Nirsoft AdapterWatch", "https://www.nirsoft.net/utils/awatch.zip", $null, $null),
    @("Nirsoft BrowserAddonsView", "https://www.nirsoft.net/utils/browseraddonsview.zip", "https://www.nirsoft.net/utils/browseraddonsview-x64.zip", $null),
    @("Nirsoft BulletsPassView", "https://www.nirsoft.net/utils/bulletspassview.zip", "https://www.nirsoft.net/utils/bulletspassview-x64.zip", $null),
    @("Nirsoft CredentialsFileView", "https://www.nirsoft.net/toolsdownload/credentialsfileview.zip", "https://www.nirsoft.net/toolsdownload/credentialsfileview-x64.zip", $null),
    @("Nirsoft Dialupass", "https://www.nirsoft.net/toolsdownload/dialupass.zip", $null, "nsdlps3861@"),
    @("Nirsoft DriveLetterView", "https://www.nirsoft.net/utils/driveletterview.zip", "https://www.nirsoft.net/utils/driveletterview-x64.zip", $null),
    @("Nirsoft DriverView", "https://www.nirsoft.net/utils/driverview.zip", "https://www.nirsoft.net/utils/driverview-x64.zip", $null),
    @("Nirsoft InstalledAppView", "https://www.nirsoft.net/utils/installedappview.zip", "https://www.nirsoft.net/utils/installedappview-x64.zip", $null),
    @("Nirsoft InstalledPackagesView", "https://www.nirsoft.net/utils/installedpackagesview.zip", "https://www.nirsoft.net/utils/installedpackagesview-x64.zip", $null),
    @("Nirsoft LostMyPassword", "https://www.nirsoft.net/utils/lostmypassword.zip", "https://www.nirsoft.net/utils/lostmypassword-x64.zip", $null),
    @("Nirsoft Mail PassView", "https://www.nirsoft.net/toolsdownload/mailpv.zip", $null, $null),
    @("Nirsoft NetworkInterfacesView", "https://www.nirsoft.net/utils/networkinterfacesview.zip", "https://www.nirsoft.net/utils/networkinterfacesview-x64.zip", $null),
    @("Nirsoft Network Password Recovery", "https://www.nirsoft.net/toolsdownload/netpass.zip", "https://www.nirsoft.net/toolsdownload/netpass-x64.zip", "ntps5291#"),
    @("Nirsoft OutlookAccountsView", "https://www.nirsoft.net/utils/outlookaccountsview.zip", "https://www.nirsoft.net/utils/outlookaccountsview-x64.zip", $null),
    @("Nirsoft OutlookAddressBookView", "https://www.nirsoft.net/utils/outlookaddressbookview.zip", $null, $null),
    @("Nirsoft Password Security Scanner", "https://www.nirsoft.net/utils/passwordscan.zip", "https://www.nirsoft.net/utils/passwordscan-x64.zip", $null),
    @("Nirsoft PCAnywhere PassView", "https://www.nirsoft.net/utils/pcanypass.zip", $null, $null),
    @("Nirsoft Product Key Scanner", "https://www.nirsoft.net/utils/productkeyscanner.zip", "https://www.nirsoft.net/utils/productkeyscanner-x64.zip", $null),
    @("Nirsoft ProduKey", "https://www.nirsoft.net/utils/produkey.zip", "https://www.nirsoft.net/utils/produkey-x64.zip", $null),
    @("Nirsoft PstPassword", "https://www.nirsoft.net/toolsdownload/pstpassword.zip", $null, $null),
    @("Nirsoft Remote Desktop PassView", "https://www.nirsoft.net/toolsdownload/rdpv.zip", $null, $null),
    @("Nirsoft SecuritySoftView", "https://www.nirsoft.net/utils/securitysoftview.zip", $null, $null),
    @("Nirsoft ShellExView", "https://www.nirsoft.net/utils/shexview.zip", "https://www.nirsoft.net/utils/shexview-x64.zip", $null),
    @("Nirsoft ShortcutsMan", "https://www.nirsoft.net/utils/shman.zip", "https://www.nirsoft.net/utils/shman-x64.zip", $null),
    @("Nirsoft UninstallView", "https://www.nirsoft.net/utils/uninstallview.zip", "https://www.nirsoft.net/utils/uninstallview-x64.zip", $null),
    @("Nirsoft VaultPasswordView", "https://www.nirsoft.net/toolsdownload/vaultpasswordview.zip", "https://www.nirsoft.net/toolsdownload/vaultpasswordview-x64.zip", $null),
    @("Nirsoft VNCPassView", "https://www.nirsoft.net/toolsdownload/vncpassview.zip", $null, $null),
    @("Nirsoft WebBrowserBookmarksView", "https://www.nirsoft.net/utils/webbrowserbookmarksview.zip", $null, $null),
    @("Nirsoft WebBrowserPassView", "https://www.nirsoft.net/toolsdownload/webbrowserpassview.zip", $null, "wbpv28821@"),
    @("Nirsoft WhatInStartup", "https://www.nirsoft.net/utils/whatinstartup.zip", "https://www.nirsoft.net/utils/whatinstartup-x64.zip", $null),
    @("Nirsoft WinMailPassRec", "https://www.nirsoft.net/utils/winmailpassrec.zip", "https://www.nirsoft.net/utils/winmailpassrec-x64.zip", $null),
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

Write-Output "Backing up Desktop..."
Log "Backing up Desktop..."
$wallpaperPath = $env:APPDATA + "\Microsoft\Windows\Themes\TranscodedWallpaper"
if (Test-Path $wallpaperPath) {
    Copy-Item -Path $wallpaperPath -Destination ".\desktop_wallpaper.jpg" -Force | Out-Null
} else {
    New-Item -Path ".\wallpaper.txt" -ItemType File -Value "No wallpaper found." -Force | Out-Null
}
.\bin\shexview.exe /shtml "desktop_shellexview.html"
.\bin\shman.exe /shtml "desktop_shortcuts_nirsoft-shortcutsman.html"
.\bin\WhatInStartup.exe /shtml "desktop_startup-programs_nirsoft-whatinstartup.html"
Write-Output "Done"
Log "Done"

Write-Output "Extracting Passwords..."
Log "Extracting Passwords..."
.\bin\BulletsPassView.exe /shtml "passwords_nirsoft-bulletspassview.html"
.\bin\CredentialsFileView.exe /shtml "passwords_nirsoft-credentialsfileview.html"
.\bin\Dialupass.exe /shtml "passwords_nirsoft-dialupass.html"
.\bin\LostMyPassword.exe /shtml "passwords_nirsoft-lostmypassword.html"
.\bin\netpass.exe /shtml "passwords_nirsoft-network-password-recovery.html"
.\bin\PasswordScan.exe /shtml "passwords_nirsoft-password-security-scanner.html"
# .\bin\PCAnyPass.exe /shtml "passwords_nirsoft-pcanywhere-passview.html"     # PCAnywhere is deprecated but may still be in use
.\bin\rdpv.exe /shtml "passwords_nirsoft-remote-desktop-passview.html"
.\bin\WebBrowserPassView.exe /shtml "passwords_nirsoft-webbrowserpassview.html"
.\bin\VaultPasswordView.exe /shtml "passwords_nirsoft-vaultpasswordview.html"
.\bin\VNCPassView.exe /shtml "passwords_nirsoft-vncpassview.html"
Write-Output "Done"
Log "Done"
Write-Output ""

Write-Output "Exporting Licenses..."
Log "Exporting Licenses..."
.\bin\ProductKeyScanner.exe /shtml "licenses_nirsoft-productkeyscanner.html"
.\bin\ProduKey.exe /shtml "licenses_nirsoft-produkey.html"
Write-Output "Done"
Log "Done"
Write-Output ""

Write-Output "Backing up Mail Clients..."
Log "Backing up Mail Clients..."
.\bin\mailpv.exe /shtml "mail-clients_nirsoft-mail-passview.html"
.\bin\OutlookAccountsView.exe /shtml "mail-clients_nirsoft-outlookaccountsview.html"
.\bin\OutlookAddressBookView.exe /shtml "mail-clients_nirsoft-outlookaddressbookview.html"
.\bin\PstPassword.exe /shtml "mail-clients_nirsoft-pstpassword.html"
.\bin\WinMailPassRec.exe /shtml "mail-clients_nirsoft-winmailpassrec.html"
reg export "HKEY_CURRENT_USER\Software\Microsoft\Windows NT\CurrentVersion\Windows Messaging Subsystem\Profiles\Outlook" "outlook_profile_2007-2010.reg" /y | Out-Null
reg export "HKEY_CURRENT_USER\Software\Microsoft\Office\15.0\Outlook" "outlook_profile_2013.reg" /y | Out-Null
reg export "HKEY_CURRENT_USER\Software\Microsoft\Office\16.0\Outlook" "outlook_profile_2016-onwards.reg" /y | Out-Null
Write-Output "Done"
Log "Done"
Write-Output ""

Write-Output "Backing up Networking..."
Log "Backing up Networking..."
.\bin\awatch.exe /shtml "networking_nirsoft-adapterwatch.html"
.\bin\NetworkInterfacesView.exe /shtml "networking_nirsoft-networkinterfacesview.html"
.\bin\WirelessKeyView.exe /export "wireless-networks_nirsoft-wirelesskeyview.txt"
Write-Output "Done"
Log "Done"
Write-Output ""

Write-Output "Backing up Devices..."
Log "Backing up Devices..."
.\bin\DriveLetterView.exe /shtml "devices_nirsoft-driveletterview.html"
hostname > hostname.txt
Get-Printer > printers.txt
Write-Output "Done"
Log "Done"
Write-Output ""

Write-Output "Backing up Web Browsers..."
Log "Backing up Web Browsers..."
.\bin\BrowserAddonsView.exe /shtml "web-browsers_nirsoft-browseraddonsview.html"
.\bin\WebBrowserBookmarksView.exe /shtml "web-browsers_nirsoft-webbrowserbookmarksview.html"
Write-Output "Done"
Log "Done"
Write-Output ""

write-Output "Exporting Installed Programs..."
Log "Exporting Installed Programs..."
if (Get-Command winget -ErrorAction SilentlyContinue) {
    winget export -o "winget.json" | Out-Null
    winget export -o "winget.json" > winget_unavailable.txt
} else {
    Write-Output "Winget not found, skipping winget export."
    Log "Winget not found, skipping winget export."
}
.\bin\InstalledAppView.exe /shtml "installed-programs_nirsoft-installedappview.html"
.\bin\InstalledPackagesView.exe /shtml "installed-programs_nirsoft-installedpackagesview.html"
.\bin\UninstallView.exe /shtml "installed-programs_nirsoft-uninstallview.html"
Write-Output "Done"
Log "Done"
Write-Output ""

Write-Output "Exporting Security Software..."
Log "Exporting Security Software..."
.\bin\SecuritySoftView.exe /shtml "security-software_nirsoft-securitysoftview.html"
Write-Output "Done"
Log "Done"
Write-Output ""


# replace this with a pause to keep the window open
Start-Sleep -Seconds 10000


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
.\bin\DriverView.exe /shtml "drivers_nirsoft-driverview.html"
write-Output "Done"
Log "Done"
Write-Output ""

Write-Output "Backuping up Registry..."
Log "Backing up Registry..."
New-Item -Path "registry" -ItemType Directory -ErrorAction SilentlyContinue | Out-Null
reg export "HKEY_CLASSES_ROOT" ".\registry\HKEY_CLASSES_ROOT.reg" /y | Out-Null
reg export "HKEY_CURRENT_USER" ".\registry\HKEY_CURRENT_USER.reg" /y | Out-Null
reg export "HKEY_LOCAL_MACHINE" ".\registry\HKEY_LOCAL_MACHINE.reg" /y | Out-Null
reg export "HKEY_USERS" ".\registry\HKEY_USERS.reg" /y | Out-Null
reg export "HKEY_CURRENT_CONFIG" ".\registry\HKEY_CURRENT_CONFIG.reg" /y | Out-Null
write-Output "Done"
Log "Done"
Write-Output ""


# replace this with a pause to keep the window open
Start-Sleep -Seconds 15