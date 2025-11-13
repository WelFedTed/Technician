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
        New-Item -ItemType File -Path $logFile -ErrorAction SilentlyContinue >> $logFile
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

Write-Output "Setting power settings to prevent sleep on AC power..."
Log "Setting power settings to prevent sleep on AC power..."
powercfg /change standby-timeout-ac 0
powercfg /change monitor-timeout-ac 0
Write-Output "Done"
Log "Done"
Write-Output ""

Write-Output "Closing non-essential applications..."
Log "Closing non-essential applications..."
Get-Process | Where-Object {$_.MainWindowTitle -ne "" -and $_.Id -ne $PID -and $_.ProcessName -ne "explorer"} | Stop-Process -Force
Write-Output "Done"
Log "Done"
Write-Output ""

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
    @("Nirsoft AdapterWatch", "https://www.nirsoft.net/utils/awatch.zip", $null, $null, "awatch.exe"),
    @("Nirsoft BrowserAddonsView", "https://www.nirsoft.net/utils/browseraddonsview.zip", "https://www.nirsoft.net/utils/browseraddonsview-x64.zip", $null, "BrowserAddonsView.exe"),
    @("Nirsoft BulletsPassView", "https://www.nirsoft.net/utils/bulletspassview.zip", "https://www.nirsoft.net/utils/bulletspassview-x64.zip", $null, "BulletsPassView.exe"),
    @("Nirsoft CredentialsFileView", "https://www.nirsoft.net/toolsdownload/credentialsfileview.zip", "https://www.nirsoft.net/toolsdownload/credentialsfileview-x64.zip", $null, "CredentialsFileView.exe"),
    @("Nirsoft Dialupass", "https://www.nirsoft.net/toolsdownload/dialupass.zip", $null, "nsdlps3861@", "Dialupass.exe"),
    @("Nirsoft DriveLetterView", "https://www.nirsoft.net/utils/driveletterview.zip", "https://www.nirsoft.net/utils/driveletterview-x64.zip", $null, "DriveLetterView.exe"),
    @("Nirsoft DriverView", "https://www.nirsoft.net/utils/driverview.zip", "https://www.nirsoft.net/utils/driverview-x64.zip", $null, "DriverView.exe"),
    @("Nirsoft InstalledAppView", "https://www.nirsoft.net/utils/installedappview.zip", "https://www.nirsoft.net/utils/installedappview-x64.zip", $null, "InstalledAppView.exe"),
    @("Nirsoft InstalledPackagesView", "https://www.nirsoft.net/utils/installedpackagesview.zip", "https://www.nirsoft.net/utils/installedpackagesview-x64.zip", $null, "InstalledPackagesView.exe"),
    @("Nirsoft LostMyPassword", "https://www.nirsoft.net/utils/lostmypassword.zip", "https://www.nirsoft.net/utils/lostmypassword-x64.zip", $null, "LostMyPassword.exe"),
    @("Nirsoft Mail PassView", "https://www.nirsoft.net/toolsdownload/mailpv.zip", $null, $null, "mailpv.exe"),
    @("Nirsoft NetworkInterfacesView", "https://www.nirsoft.net/utils/networkinterfacesview.zip", "https://www.nirsoft.net/utils/networkinterfacesview-x64.zip", $null, "NetworkInterfacesView.exe"),
    @("Nirsoft Network Password Recovery", "https://www.nirsoft.net/toolsdownload/netpass.zip", "https://www.nirsoft.net/toolsdownload/netpass-x64.zip", "ntps5291#", "netpass.exe"),
    @("Nirsoft NTFSLinksView", "https://www.nirsoft.net/utils/ntfslinksview.zip", "https://www.nirsoft.net/utils/ntfslinksview-x64.zip", $null, "NTFSLinksView.exe"),
    @("Nirsoft OutlookAccountsView", "https://www.nirsoft.net/utils/outlookaccountsview.zip", "https://www.nirsoft.net/utils/outlookaccountsview-x64.zip", $null, "OutlookAccountsView.exe"),
    @("Nirsoft OutlookAddressBookView", "https://www.nirsoft.net/utils/outlookaddressbookview.zip", $null, $null, "OutlookAddressBookView.exe"),
    @("Nirsoft Password Security Scanner", "https://www.nirsoft.net/utils/passwordscan.zip", "https://www.nirsoft.net/utils/passwordscan-x64.zip", $null, "PasswordScan.exe"),
    # @("Nirsoft PCAnywhere PassView", "https://www.nirsoft.net/utils/pcanypass.zip", $null, $null, "PCAnyPass.exe"),
    @("Nirsoft Product Key Scanner", "https://www.nirsoft.net/utils/productkeyscanner.zip", "https://www.nirsoft.net/utils/productkeyscanner-x64.zip", $null, "ProductKeyScanner.exe"),
    @("Nirsoft ProduKey", "https://www.nirsoft.net/utils/produkey.zip", "https://www.nirsoft.net/utils/produkey-x64.zip", $null, "ProduKey.exe"),
    @("Nirsoft PstPassword", "https://www.nirsoft.net/toolsdownload/pstpassword.zip", $null, $null, "PstPassword.exe"),
    @("Nirsoft Remote Desktop PassView", "https://www.nirsoft.net/toolsdownload/rdpv.zip", $null, $null, "rdpv.exe"),
    @("Nirsoft SecuritySoftView", "https://www.nirsoft.net/utils/securitysoftview.zip", $null, $null, "SecuritySoftView.exe"),
    @("Nirsoft ShellExView", "https://www.nirsoft.net/utils/shexview.zip", "https://www.nirsoft.net/utils/shexview-x64.zip", $null, "shexview.exe"),
    @("Nirsoft ShortcutsMan", "https://www.nirsoft.net/utils/shman.zip", "https://www.nirsoft.net/utils/shman-x64.zip", $null, "shman.exe"),
    @("Nirsoft TaskSchedulerView", "https://www.nirsoft.net/utils/taskschedulerview.zip", "https://www.nirsoft.net/utils/taskschedulerview-x64.zip", $null, "TaskSchedulerView.exe"),
    @("Nirsoft UserProfilesView", "https://www.nirsoft.net/utils/userprofilesview.zip", $null, $null, "UserProfilesView.exe"),
    @("Nirsoft UninstallView", "https://www.nirsoft.net/utils/uninstallview.zip", "https://www.nirsoft.net/utils/uninstallview-x64.zip", $null, "UninstallView.exe"),
    @("Nirsoft VaultPasswordView", "https://www.nirsoft.net/toolsdownload/vaultpasswordview.zip", "https://www.nirsoft.net/toolsdownload/vaultpasswordview-x64.zip", $null, "VaultPasswordView.exe"),
    @("Nirsoft VNCPassView", "https://www.nirsoft.net/toolsdownload/vncpassview.zip", $null, $null, "VNCPassView.exe"),
    @("Nirsoft WebBrowserBookmarksView", "https://www.nirsoft.net/utils/webbrowserbookmarksview.zip", $null, $null, "WebBrowserBookmarksView.exe"),
    @("Nirsoft WebBrowserPassView", "https://www.nirsoft.net/toolsdownload/webbrowserpassview.zip", $null, "wbpv28821@", "WebBrowserPassView.exe"),
    @("Nirsoft WhatInStartup", "https://www.nirsoft.net/utils/whatinstartup.zip", "https://www.nirsoft.net/utils/whatinstartup-x64.zip", $null, "WhatInStartup.exe"),
    @("Nirsoft WinMailPassRec", "https://www.nirsoft.net/utils/winmailpassrec.zip", "https://www.nirsoft.net/utils/winmailpassrec-x64.zip", $null, "WinMailPassRec.exe"),
    @("Nirsoft WirelessKeyView", "https://www.nirsoft.net/toolsdownload/wirelesskeyview.zip", "https://www.nirsoft.net/toolsdownload/wirelesskeyview-x64.zip", "WKey4567#", "WirelessKeyView.exe"),
    @("Rclone", "https://downloads.rclone.org/rclone-current-windows-386.zip", "https://downloads.rclone.org/rclone-current-windows-amd64.zip", $null, "rclone.exe"),
    @("UVK", "https://www.carifred.com/uvk/UVK.zip", $null, $null, "UVK_en64.exe"),
    @("WizTree", "https://diskanalyzer.com/files/wiztree_4_27_portable.zip", $null, $null, "WizTree64.exe")
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
    } else {
        if ($password) {
            .\bin\7za.exe e $outputPath -o"bin" -p"$password" -y >> $logFile
        } else {
            .\bin\7za.exe e $outputPath -o"bin" -y >> $logFile
        }
    }

    Remove-Item -Path $outputPath -Force

    Write-Output "Done"
    Log "Done"
    Write-Output ""
}

# cmd /k pause

Write-Output "Backing up Desktop..."
Log "Backing up Desktop..."
$wallpaperPath = $env:APPDATA + "\Microsoft\Windows\Themes\TranscodedWallpaper"
if (Test-Path $wallpaperPath) {
    Copy-Item -Path $wallpaperPath -Destination ".\desktop_wallpaper.jpg" -Force >> $logFile
} else {
    New-Item -Path ".\wallpaper.txt" -ItemType File -Value "No wallpaper found." -Force >> $logFile
}
.\bin\NTFSLinksView.exe /shtml "symlinks_nirsoft-ntfslinksview.html"
.\bin\shexview.exe /shtml "shell-extensions_nirsoft-shellexview.html"
.\bin\shman.exe /shtml "shortcuts_nirsoft-shortcutsman.html"
.\bin\TaskSchedulerView.exe /shtml "scheduled-tasks_nirsoft-taskschedulerview.html"
.\bin\UserProfilesView.exe /shtml "user-profiles_nirsoft-userprofilesview.html"
.\bin\WhatInStartup.exe /shtml "startup-items_nirsoft-whatinstartup.html"
if ([Environment]::Is64BitOperatingSystem) {
    .\bin\UVK_en64.exe -WriteSysInfo "$directory\system-info.html"
} else {
    .\bin\UVK_en.exe -WriteSysInfo "$directory\system-info.html"
}
net users > users.txt
Write-Output "Done"
Log "Done"
write-Output ""

Write-Output "Extracting Passwords..."
Log "Extracting Passwords..."
.\bin\BulletsPassView.exe /shtml "passwords_nirsoft-bulletspassview.html"
.\bin\CredentialsFileView.exe /shtml "passwords_nirsoft-credentialsfileview.html"   # no cli export
.\bin\Dialupass.exe /shtml "passwords_nirsoft-dialupass.html"                       # no cli export
.\bin\LostMyPassword.exe /shtml "passwords_nirsoft-lostmypassword.html"             # no cli export
.\bin\netpass.exe /shtml "passwords_nirsoft-network-password-recovery.html"         # no cli export
.\bin\PasswordScan.exe /shtml "passwords_nirsoft-password-security-scanner.html"    # no cli export
# .\bin\PCAnyPass.exe /shtml "passwords_nirsoft-pcanywhere-passview.html"           # PCAnywhere is deprecated but may still be in use
.\bin\rdpv.exe /shtml "passwords_nirsoft-remote-desktop-passview.html"              # no cli export
.\bin\WebBrowserPassView.exe /shtml "passwords_nirsoft-webbrowserpassview.html"     # no cli export
.\bin\VaultPasswordView.exe /shtml "passwords_nirsoft-vaultpasswordview.html"       # no cli export
.\bin\VNCPassView.exe /shtml "passwords_nirsoft-vncpassview.html"
Write-Output "Done"
Log "Done"
Write-Output ""

Write-Output "Exporting Licenses..."
Log "Exporting Licenses..."
.\bin\ProductKeyScanner.exe /shtml "licenses_nirsoft-productkeyscanner.html"        # no cli export
.\bin\ProduKey.exe /shtml "licenses_nirsoft-produkey.html"
Write-Output "Done"
Log "Done"
Write-Output ""

Write-Output "Backing up Mail Clients..."
Log "Backing up Mail Clients..."
.\bin\mailpv.exe /shtml "mail-clients_nirsoft-mail-passview.html"                       # no cli export
.\bin\OutlookAccountsView.exe /shtml "mail-clients_nirsoft-outlookaccountsview.html"    # no cli export
.\bin\OutlookAddressBookView.exe /shtml "mail-clients_nirsoft-outlookaddressbookview.html"
.\bin\PstPassword.exe /shtml "mail-clients_nirsoft-pstpassword.html"                    # no cli export
.\bin\WinMailPassRec.exe /shtml "mail-clients_nirsoft-winmailpassrec.html"              # no cli export
reg export "HKEY_CURRENT_USER\Software\Microsoft\Windows NT\CurrentVersion\Windows Messaging Subsystem\Profiles\Outlook" "outlook_profile_2007-2010.reg" /y >> $logFile
reg export "HKEY_CURRENT_USER\Software\Microsoft\Office\15.0\Outlook" "outlook_profile_2013.reg" /y >> $logFile
reg export "HKEY_CURRENT_USER\Software\Microsoft\Office\16.0\Outlook" "outlook_profile_2016-onwards.reg" /y >> $logFile
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
net use > mapped-drives.txt
Get-Printer > printers.txt
if ([Environment]::Is64BitOperatingSystem) {
    .\bin\WizTree64.exe "$directory" /export="wiztree.csv"
} else {
    .\bin\WizTree.exe "$directory" /export="wiztree.csv"
}
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
    winget export -o "winget.json" --accept-source-agreements >> $logFile
    winget export -o "winget.json" --accept-source-agreements > winget_unavailable.txt
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
New-Item -Path "drivers" -ItemType Directory -ErrorAction SilentlyContinue >> $logFile
Export-WindowsDriver -Online -Destination ".\drivers"
.\bin\DriverView.exe /shtml "drivers_nirsoft-driverview.html"
write-Output "Done"
Log "Done"
Write-Output ""

Write-Output "Backuping up Registry..."
Log "Backing up Registry..."
New-Item -Path "registry" -ItemType Directory -ErrorAction SilentlyContinue >> $logFile
reg export "HKEY_CLASSES_ROOT" ".\registry\HKEY_CLASSES_ROOT.reg" /y >> $logFile
reg export "HKEY_CURRENT_USER" ".\registry\HKEY_CURRENT_USER.reg" /y >> $logFile
reg export "HKEY_LOCAL_MACHINE" ".\registry\HKEY_LOCAL_MACHINE.reg" /y >> $logFile
reg export "HKEY_USERS" ".\registry\HKEY_USERS.reg" /y >> $logFile
reg export "HKEY_CURRENT_CONFIG" ".\registry\HKEY_CURRENT_CONFIG.reg" /y >> $logFile
write-Output "Done"
Log "Done"
Write-Output ""

Write-Output "Resetting power settings..."
Log "Resetting power settings..."
powercfg /restoredefaultschemes >> $logFile
Write-Output "Done"
Log "Done"
Write-Output ""

Write-Output "Backup Complete"
Log "----------------------------------------"
Log "Backup Complete"
Log "----------------------------------------"

cmd /k pause