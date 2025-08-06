<!-- COPS Technician Manual -->

# Application Cheat Sheet

## CPU

| TASK   | APPLICATION                                         | WINGET      | DISABLE ANTIVIRUS | NOTES |
| :----- | :-------------------------------------------------- | :---------- | :---------------: | :---- |
| Info   | [CPU-Z](https://www.cpuid.com/softwares/cpu-z.html) | CPUID.CPU-Z |         ✕         |       |
| Stress | [CPU-Z](https://www.cpuid.com/softwares/cpu-z.html) | CPUID.CPU-Z |         ✕         |       |

## GPU

| TASK                   | APPLICATION                                                                                              | WINGET                               | DISABLE ANTIVIRUS | NOTES                        |
| :--------------------- | :------------------------------------------------------------------------------------------------------- | :----------------------------------- | :---------------: | :--------------------------- |
| Driver (Update-AMD)    | [AMD Adrenalin](https://www.amd.com/en/products/software/adrenalin.html)                                 | -                                    |         ✕         |                              |
| Driver (Update-INTEL)  | [Intel HD Graphics](https://www.intel.com/content/www/us/en/support/products/80939/graphics.html)        | -                                    |         ✕         |                              |
| Driver (Update-NVIDIA) | [Nvidia App](https://www.nvidia.com/en-au/software/nvidia-app/)                                          | -                                    |         ✕         |                              |
| Driver (Uninstall)     | [Display Driver Uninstaller (DDU)](https://www.guru3d.com/download/display-driver-uninstaller-download/) | Wagnardsoft.DisplayDriverUninstaller |         ✕         | _Boot into Safe Mode to use_ |
| Info                   | [GPU-z](https://www.techpowerup.com/download/techpowerup-gpu-z/)                                         | TechPowerUp.GPU-Z                    |         ✕         |                              |
| Stress                 | [Furmark](https://www.geeks3d.com/furmark/)                                                              | Geeks3D.FurMark                      |         ✕         |                              |

## STORAGE

| TASK      | APPLICATION                                                              | WINGET                          | DISABLE ANTIVIRUS | NOTES                              |
| :-------- | :----------------------------------------------------------------------- | :------------------------------ | :---------------: | :--------------------------------- |
| Benchmark | [CrystalDiskMark](https://crystalmark.info/en/software/crystaldiskmark/) | CrystalDewWorld.CrystalDiskMark |         ✕         |                                    |
| Clone     | [MiniTool Partition Wizard](https://www.partitionwizard.com/)            | MiniTool.PartitionWizard.Free   |         ✕         | _Bootable full version on Medicat_ |
| Info      | [CrystalDiskInfo](https://crystalmark.info/en/software/crystaldiskinfo/) | CrystalDewWorld.CrystalDiskInfo |         ✕         |                                    |
| Info      | [Clear Disk Info](https://www.carifred.com/cleardiskinfo/)               | -                               |         ✕         |                                    |

## SYSTEM

| TASK         | APPLICATION                                                 | WINGET          | DISABLE ANTIVIRUS | NOTES |
| :----------- | :---------------------------------------------------------- | :-------------- | :---------------: | :---- |
| Temperatures | [HWMonitor](https://www.cpuid.com/softwares/hwmonitor.html) | CPUID.HWMonitor |         ✕         |       |

## WINDOWS

| TASK                                   | APPLICATION                                                                                            | WINGET                                   |          DISABLE ANTIVIRUS           | NOTES                                                                           |
| :------------------------------------- | :----------------------------------------------------------------------------------------------------- | :--------------------------------------- | :----------------------------------: | :------------------------------------------------------------------------------ |
| Blue Screens (Check STOP-Codes/Errors) | [BlueScreenView](https://www.nirsoft.net/utils/blue_screen_view.html)                                  | NirSoft.BlueScreenView                   |                  ✕                   |                                                                                 |
| Drivers (Verify)                       | [Verifier](https://learn.microsoft.com/en-us/windows-hardware/drivers/devtest/driver-verifier)         | Win+R: verifier                          |                  ✕                   | _Built-in to Windows_                                                           |
| Drivers (Update)                       | [Snappy Driver Installer Origin (SDIO)](https://www.glenn.delahoy.com/snappy-driver-installer-origin/) | GlennDelahoy.SnappyDriverInstallerOrigin |                  ✕                   |                                                                                 |
| License Keys (Extract)                 | [Product Key Scanner](https://www.nirsoft.net/utils/product_key_scanner.html)                          | -                                        | <font style="color:red">**✓**</font- | _Extract license keys for Windows and/or Office_                                |
| License Keys (Extract)                 | [ProduKey](https://www.nirsoft.net/utils/product_cd_key_viewer.html)                                   | -                                        | <font style="color:red">**✓**</font- | _May find licenses for some older products that Product Key Scanner could miss_ |
| Software (Uninstall + Remnant Removal) | [RevoUninstaller](https://www.revouninstaller.com/)                                                    | RevoUninstaller.RevoUninstaller          |                  ✕                   |                                                                                 |
| Remote Access                          | [TeamViewer](https://www.teamviewer.com/en-au/)                                                        | winget install TeamViewer.TeamViewer     |                  ✕                   | _May run into connection limit on free version_                                 |
| Remote Access                          | [UltraViewer](https://www.ultraviewer.net/en/)                                                         | winget install DucFabulous.UltraViewer   |                  ✕                   | _Alternative to TeamViewer_                                                     |
| User Profile (Backup/Migrate)          | [Transwiz](https://www.forensit.com/move-computer.html)                                                | -                                        |                  ✕                   |                                                                                 |


<!-- Render to .PDF using https://md2pdf.netlify.app/ at 75% scaling (Print to PDF) -->

# System Service (Windows)

## Software

- Restart Windows
- Configure System Restore</br>_Try to set at least 7% allocation_
- Create a new System Restore point</br>_Name it something like "COPS - Pre System Service"_
- Task Manager
  - Disable unwanted startup items
- [Wintoys](https://apps.microsoft.com/detail/9p8ltpgcbzxd)
  - Install [Wintoys](https://apps.microsoft.com/detail/9p8ltpgcbzxd)\
    `winget install wintoys`\
    or\
    `winget install 9P8LTPGCBZXD`</br>
    or\
    `ms-windows-store://pdp/?ProductId=9P8LTPGCBZXD`
  - Performance Tab
    - `Ultimate performance power plan` | Turn ON if Desktop / Turn OFF if Laptop
    - `HAGS (hardware-accelerated GPU scheduling)` | Turn ON
    - `VBS (virtualization-base security)` | Turn ON
    - `Startup apps` | Disable unwanted startup items
    - `Search indexing` | Turn ON
    - `Delivery optimization` | Turn ON
    - `Network adapter onboard processor` | Turn ON
  - Health Tab
    - `Fast startup` | Turn ON
    - `Drive optimization` | Turn ON and run (click config icon and optimise each drive)
    - `Storage sense` | Turn ON and run (click config icon and click 'Run Storage Sense now')
    - `Cleanup` | Run 'Junk' + 'Microsoft Store' + 'DNS'
    - `System updates` | Set to 'Default'
    - `App updates` | Turn ON
    - `Graphics driver` | Click 'Restart'
    - `Icons cache` | Click 'Rebuild'
  - Tweaks Tab
    - `Desktop` | Turn ON 'This PC' + 'Recycle Bin'
- Update software
  - Windows Update
    - _old Windows 10 builds can use the Windows 10 Update Assistant to jump to the latest build_
  - Update Apps via Winget
  - Update Apps via Microsoft Store
  - Update Office Apps
- Update Drivers
  - Update Drivers using `SDIO`
  - Verify Drivers using `verifier`
- Maintenance
  - Run the following commands:
    - sfc /scannow</br>
    - dism /online /cleanup-image /startcomponentcleanup /resetbase</br>
    - dism /online /cleanup-image /restorehealth</br>
    - sfc /scannow</br>
    - chkdsk c: /r /scan /perf</br>
    - defrag c: /o
  - Disk Cleanup
    - Run `cleanmgr /sageset:10`
    - Click `Clean up system files`
    - Tick all checkboxes EXCEPT:</br>
    `System error memory dump files`</br>
    `System error minidump files`</br>
    `Windows error reports and feedback diagnostics`</br>
    `User file history`
    - Click `OK`
    - Run `cleanmgr /sagerun:10`
  - Memory Diagnostics
    - Run `Windows Memory Diagnostics`
    - Click 'Restart now and check for problems (recommended)'
    - After Windows boots back up, check results:</br>
      `Event Viewer` - Windows Logs - System - Filter Current Log... - Event sources - Tick 'MemoryDiagnostics-Results' - Click OK
  - Create a new System Restore point</br>_Name it something like "COPS - Post System Service"_

## Hardware

- Check all buttons and ports are free from debris and working functioning correctly
- Air compress out system as required
- Wipe down device and clean surfaces
- Add a `Serviced by COPS` sticker or replace old worn stickers as required

# Data Transfer (Windows)

## Backup

- **Restart Windows**\
  - _Force Restart Windows now to provide a clean environment for proceeding_\
  - `shutdown -r -f -t 00`
- [<font style="color:ORANGE">OPTIONAL</font>] Create a new System Restore point
- **Disable Antivirus**\
  - _Some of our extraction tools prompt false positives in the majority of security software_
- **Create a Job folder on a Transfer Drive**\
  _naming convention:_\
  `Job#5000`
  - _Create a new folder with the current job number to save User Data to_
- **Backup User Profiles**\
  - _Copy `C:\Users\` folder to the Job folder on the Transfer Drive_
- **Backup Web Browsers**\
  _For each web browser installed complete the following:_
  - **Export Bookmarks**\
    _naming convention:_\
    `Web Browser - Google Chrome - Bookmarks - 2024-07-15.html`\
    or\
    `web-browser_google-chrome_bookmarks_2024-07-15.html`
    - _Google Chrome URL:_ `chrome://bookmarks`\
    - _Microsoft Edge URL:_ `edge://favorites`\
    - _AVG Secure Browser URL:_ `secure://bookmarks`\
    - _Mozilla Firefox Hotkey:_ `Ctrl+Shift+O`\
    - _Microsoft Internet Explorer:_ `%USERPROFILE%\Favorites`
  - **Export Passwords**\
    _naming convention:_\
    `Web Browser - Google Chrome - Passwords - 2024-07-15.csv`\
    or\
    `web-browser_google-chrome_passwords-2024-07-15.csv`
    - _Google Chrome URL:_ `chrome://password-manager` or `chrome://settings/passwords` (older Chrome versions)\
    - _Microsoft Edge URL:_ `edge://wallet/passwords` or `edge://settings/passwords` (older Edge versions)\
    - _AVG Secure Browser URL:_ `secure://password-manager` or `secure://settings/passwords` (older Secure Browser versions)\
    - _Mozilla Firefox URL:_ `about:logins`\
    - _Microsoft Internet Explorer:_ use [Nirsoft IE PassView](https://www.nirsoft.net/utils/internet_explorer_password.html)
  - **Sync Accounts**\
    _Try to sync each browser with their relevant accounts if available_\
    _Manual exports of Bookmarks + Passwords is good, but syncing the entire browser is better_
    - _Google Chrome:_ `Google Account`
      - `chrome://sync-internals`\
      - Check Enabled: `Sync Feature Enabled`	= true\
      - Check Account: `Username`\
      - Checked Synced: `Last Synced` = Just now\
      - Check Not Actively Syncing: `Sync Cycle Ongoing` = false\
      - Force Sync (if required): `chrome://extensions` - enable `Developer mode` - click `Update`\
    - _Microsoft Edge:_ `Microsoft Account`
      - _TODO (but it's similar to Chrome)_\
    - _AVG Secure Browser:_ `AVG Account`
      - _TODO (but it's similar to Chrome)_\
    - Mozilla Firefox:_ `Mozilla Account`
      - _TODO_
- **Export Installed Programs List**\
  _naming convention:_\
  `Installed Programs - Nirsoft Uninstallview - 2024-07-15.html`\
  or\
  `installed-programs_nirsoft-uninstallview_2024-07-15.html`
  - _use Nirsoft UninstallView, save all as Horizontal HTML_
- **Export Winget**\
  _naming convention:_\
  `Winget - Export - 2024-07-15.json`\
  or\
  `winget_export_2024-07-15.json`
  - Open `Powershell` or `Command Prompt` as an Administrator\
  - Check Winget is installed `winget -v` (this will throw an error if winget is unavailable)\
  - Update Winget `winget source update`
  - Export Winget's list of installed programs `winget export -o "REPLACE-WITH-TARGET-FILE"`\
  _(update REPLACE-WITH-TARGET-FILE with the target winget export file on the transfer drive)_\
  - Optionally export a list of all programs that Winget does cannot re-install at the same time with this extended command `winget export -o "REPLACE-WITH-TARGET-FILE" >- "winget_unnavailable.txt"`
- **Export License Keys**\
  _naming convention:_\
  `License Keys - Nirsoft Product Key Scanner - 2024-07-15.html`\
  or\
  `license-keys_nirsoft-product-key-scanner_2024-07-15.html`
  - _use Nirsoft Product Key Scanner or Nirsoft ProduKey, save all as Horizontal HTML_
- **Export Emails**
  - Extract Passwords and Server Settings
    - Nirsoft Mail PassView
    - Nirsoft WinMailPassRec
    - Nirsoft PstPassword
  - Backup any accounts set up as POP
    - [_How to export emails to file in Outlook_](https://support.microsoft.com/en-au/office/back-up-your-email-e5845b0b-1aeb-424f-924c-aa1c33b18833)
- **Check C: Drive for unusual files/folders**
  - _copy to Job folder copying the C: Drive file structure (TransferDrive:\\Job\#5000\\C\\FolderToSave)_
- [<font style="color:ORANGE">OPTIONAL</font>] Create Winget Install Script
  - _https://winstall.app/ - Select Desired Programs - Generate Script - Download both Batch (.bat) and PowerShell (.ps1) scripts_
- **Export Drivers**\
  `TRANSFERDRIVE:\\Job#5000\Drivers - 2024-07-15\`\
  or\
  `TRANSFERDRIVER:\\Job#5000\drivers_2024-07-15\`
  - _Open `PowerShell` as an Administrator and run the following script:_\
  `Export-WindowsDriver -Online -Destination "REPLACE-WITH-TARGET-FOLDER"`\
  _(update REPLACE-WITH-TARGET-FOLDER with the target drivers folder on the transfer drive)_
- **Enable Antivirus**

## Prepare New Device _(if required)_

- **Create a Local Account during Windows 10/11 Out of Box Experience (OOBE)**
  - **Option 1: No Internet Connected**\
    Bypass Network Registration
    - _Open Command Prompt:_ `Shift+F10` _(may require pressing `Fn` on some devices)_\
    - _Run command:_ `OOBE\BYPASSNRO` _(this will restart the OOBE if successful)_\
    - _Proceed through OOBE like normal until you get to the Network Selection screen_\
    - _Select_ `I don't have an internet connection` _(if this button is not available the bypass didn't work, proceed to Option 2)_\
    - _Select_ `Continue with limited setup`\
    - _Create a Local Account:_ `COPS` (no password)\
    - _Complete the OOBE as normal_
  - **Option 2: Internet Connected**\
    Force Local Account Creation
    - _Proceed though OOBE like normal until you get to the Login with a Microsoft Account screen_\
    - _Open Command Prompt:_ `Shift+F10` _(may require pressing `Fn` on some devices)_\
    - _Run command:_ `start ms-cxh:localonly`
    - _Create a Local Account:_ `COPS` (no password)\
    - _Complete the OOBE as normal_
  - Note regarding Windows 10/11 S Mode\
    In some cases you won't be able to open the Command Prompt, you may only see it's black box flash up on the screen and quickly dissapear. This is could be a indication of the Windows 10/11 install being in S Mode (Store Mode), which disables access to terminals (i.e. Command Prompt) and execution of non Microsoft Store apps.\
    If you encounter this, you will <u>not</u> be able create a Local Account during the OOBE, and you will need to complete the OOBE with the customer's Microsoft Account.
    After the OOBE is complete and you've reached the Windows Desktop environment, you may need to [Switch Out of S Mode](https://support.microsoft.com/en-au/windows/switching-out-of-s-mode-in-windows-4f56d9be-99ec-6983-119f-031bfb28a307) to proceed with the Data Transfer, as S Mode restricts us from running our tools if required.
    - [<font style="color:ORANGE">OPTIONAL</font>] Switch Out of S Mode\
    <font style="color:RED">WARNING: SWITCHING OUT OF S MODE IS A PERMANANT CHANGE AND <u>CANNOT</u> BE REVERTED</font>
      - _Connect to the internet_\
      - _Run_ `ms-windows-store://pdp/?productid=BF712690PMLF&OCID=windowssmodesupportpage`\
      - _Follow the prompts to Switch Out of S Mode\
      (this will change the Windows edition installed to Windows 10/11 Home or Pro as per it's installed license)_
- **Configure System Restore**\
- **Check installed Windows' Edition**\
  - _Run_ `winver`
- **Create a new System Restore point**\
  `COPS - Fresh Windows 10/11 Home/Pro Install` (use 10 or 11 and Home or Pro as per `winver`)
- **Connect to the Internet** (if not already)
- **Check Windows is activated**\
  TODO: `ms-settings:activation` or `ms-settings:activation?activationSource=SMC-Article-12440`
- **Configure Time/Date**
- **Configure Windows Update**
  - _Enable_ `TODO: Update other Microsoft products`\
  - _Disable_ `TODO: get me up to date`\
  - _Enable_ `TODO: Notify me when updates are ready`\
  - _Enable_ `TODO: Optimize, download from LAN`
- **Update Apps**\
  via `Microsoft Store`\
  via `Winget`
- **Update Windows**
- **Update Office apps**\
  - Run `"C:\Program Files\Common Files\microsoft shared\ClickToRun\OfficeC2RClient.exe" /update user forceappshutdown=true`
- **Check Drivers**\
  Bangs(!) exclamation marks in Device Manager indicates missing, incorrect, or corrupt drivers
  - Open `Device Manager` to check for Bangs(!)
  - Run `Snappy Driver Installer Origin (SDIO)` as an Administrator
  - Select `TODO: Create a new system restore point`
  - Select all missing/incorrect/corrupt drivers (as per bangs! in Device Manager)
  - Click `Install`
- **[<font style="color:ORANGE">OPTIONAL</font>] Update Outdated Drivers**
- **Verify Drivers**
  - **Turn On Windows Verifier:**
    - Run `verifier`
    - Select `Create standard settings`
    - Click `Next`
    - Select `Automatically select all drivers on this computer`
    - Click `Finish`
    - Restart Windows `shutdown -r -f -t 00`
      - _Windows Verifier works by stressing out drivers as they're loaded (it is expected that the computer's performance will be impacted while verifier is enabled)_\
      - _If Windows loads into the desktop OK and does not crash with Verifier enabled, then all is good and you can proceed to turn it off_\
      - _If Verifier induces a crash, Windows should produce a Blue Screen of Death (BSOD) with a STOP Code error and information on the driver that crashed, you can use this information to identify the faulty driver that caused the crash and replace it_
  - **Turn Off Windows Verifier:**
    - Run `verifier`
    - Select `Delete existing settings`
    - Click `Finish`
    - Restart Windows `shutdown -r -f -t 00`

## Restore

- **Install Programs**
  - you can use the winget install script for this if you made one \ - _install programs before restoring the user profile, as otherwise some required registry entries may not exist yet_
- **Restore User Profiles**
  - make Administrator, make default user, set no password and set password does NOT expire
- **Copy over any C: Drive files/folders that were backed up**
- **Restart Windows** (this should log in to the restored user profile)
  - open a command prompt window (or similar) as Administrator to ensure account has admin priviledges
- **Install Printer Drivers**
  - If you can not install the printer drivers + software without the printer present, save the printer package installer to `C:\COPS\` and create a shortcut to it on the customer's desktop
- **Check Web Browsers and restore Bookmarks and Passwords from backups as required**
- **Activate software using extracted keys or accounts as required**
- **Configure email accounts as required**
- **Install additional drivers as required**
- **Move any USB Dongles from the old device (Wireless mice, wifi, blue adapters, etc...)**
- **Update Apps**\
  via `Microsoft Store`\
  via `Winget`
- **Update Windows**
- **Update Office apps** (if installed)
- **Restart Windows**
- **Remove 'COPS' user account**
  - Run: `netplwiz` - Select `COPS` - Click `Remove`
  - Delete `C:\Users\COPS\` folder\
  _(Windows may prevent you from removing this folder if it's currently accessing it in the background, if this happens just restart Windows and try to remove it again)_
  - Empty Recycle Bin
- **System Maintenance**\
  Open `Powershell` or `Command Prompt` as an Administrator and run the follow commands:
  ```batch
  winget source reset --force
  winget source update
  winget upgrade --all --silent
  sfc /scannow
  dism /online /cleanup-image /startcomponentcleanup /resetbase
  dism /online /cleanup-image /restorehealth
  sfc /scannow
  defrag /c /o
  chkdsk c: /r /scan /perf
  ```
- **Restart Windows**
- **Create a new System Restore point** `COPS - Completed Data Transfer`

# Virus/Malware Removal (Windows)
<!--
    TO DO:
    - fill out large tasks sub-tasks (revo, cleanmgr, uvk, verifier, etc..)
    - document more comprehensively with tooltips and/or images
    - mouse over tool tips
        [Display text](## "Hover text")
    - implement coloured text and improved document formatting
    - make markdown doc work with a technician wiki? (Obsidian knowledgebase?)
-->

## Pre

- [<font style="color:RED">**IMPORTANT**</font>] [Air Gap Device](## "AAA")
  > _Ensure device is disconnected from all networks before RKill is run successfully and RATs ( Remote Access Tools ) removed, to ensure malicious actors do not re-connect to the device while it's still compromised_
- Enable System Restore (set to 7% allocation if enough free disk space)
- [<font style="color:ORANGE">OPTIONAL</font>] Create a new [System Restore](https://support.microsoft.com/en-gb/windows/create-a-system-restore-point-77e02e2a-3298-c869-9974-ef5658ea3be9) point "**COPS - Pre Virus/Malware Removal**"
  > _This System Restore point will be wiped out in a later step (post-virus/malware removal), as malware can persist in old System Restore points_
- Restart Windows
  > _Force Restart Windows (`shutdown -r -f -t 00`) now to provide a clean slate for proceeding_
- Create [COPS Folder](## "'%SYSTEMDRIVE%\\COPS' ( likely 'C:\COPS' )")
- Add [COPS Folder](## "'%SYSTEMDRIVE%\\COPS' ( likely 'C:\COPS' )") to installed [antivirus exclusions list(s)](https://support.microsoft.com/en-au/windows/add-an-exclusion-to-windows-security-811816c0-4dfd-af4a-47e4-c301afe13b26 "How to add an exclusion to Windows Security")
- Copy RKill folder from USB Tool to "%SYSTEMDRIVE%\COPS" (RKill can't run from a write-blocked drive)
- [<font style="color:RED">**IMPORTANT**</font>] Run an RKill executable as Administrator
- Move RKill.txt from "%USERPROFILE%\Desktop" to "%SYSTEMDRIVE%\COPS"
- Revo Uninstaller
  - xxx
- Disk Cleanup
  - Run `Win+R`: `cleanmgr /sageset:10`
    > _This will open the Disk Cleanup utility to create settings for Profile 10_
  - Click `Clean up system files`
  - Select all checkboxes except for the two **System error** options
    > _`System error memory dump files` + `System error minidump files`_ >_</br>(you can click on an option, and then use the UP + DOWN Arrows + Space Bar to quickly check or uncheck options)_
  - Click `OK`
  - Run `Win+R`: `cleanmgr /sagerun:10`
    > _This will run the Disk Cleanup utility to using Profile 10's settings`_

## Main

- Connect to Internet
- [<font style="color:ORANGE">OPTIONAL</font>] [AdwCleaner](https://www.malwarebytes.com/adwcleaner)
  > _AdwCleaner crashes out of UVK's automation, so run it now instead if you want to use it_
- [<font style="color:ORANGE">OPTIONAL</font>] [Spybot - Search & Destroy](https://www.safer-networking.org/free-download/)
  > _Spybot is a thorough malware removal tool, but it can take a very long time to complete it's scans_
- [<font style="color:ORANGE">OPTIONAL</font>] [Windows Defender Offline Scan](https://support.microsoft.com/en-au/windows/help-protect-my-pc-with-microsoft-defender-offline-9306d528-64bf-4668-5b80-ff533f183d6c "How to use Windows Defender Offline")
- [<font style="color:ORANGE">OPTIONAL</font>] Create a new System Restore point "**COPS - Pre Virus/Malware Removal**"
- [Ultra Virus Killer (UVK)](https://www.carifred.com/uvk/)
  - Install UVK
  - Open UVK
    - Do <u>not</u> disable Hybrid Shutdown if asked when opening UVK
    - Do Update UVK if asked when opening UVK
  - Click System Repair
  - Select the following repair actions: _(left menu)_
    > _(you can click on an option, and then use the UP + DOWN Arrows + Space Bar to quickly check or uncheck options)_</br>
    - **Pre-Repair Actions**</br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;1. Set technician power settings</br>&nbsp;&nbsp;&nbsp;&nbsp; 2. Kill all non system processes</br>&nbsp;&nbsp;&nbsp;&nbsp; 3. Delete all restore points</br>&nbsp;&nbsp;&nbsp;&nbsp; 4. Create a system restore point</br>&nbsp;&nbsp;&nbsp;&nbsp; 5. Free physical memory</br>&nbsp;&nbsp;&nbsp;&nbsp; 6. Backup the registry</br>&nbsp;&nbsp;&nbsp;&nbsp; 7. Un-immunize all areas</br>&nbsp;&nbsp;&nbsp;&nbsp; 8. Disable the User Account Control</br>&nbsp;&nbsp;&nbsp;&nbsp; 9. Enable the legacy (F8) boot menu</br>&nbsp;&nbsp;&nbsp;&nbsp; 10. Enable Windows Recovery Environment</br>&nbsp;&nbsp;&nbsp;&nbsp; 11. Prevent rebooting until all is done</br>
    - **Third-Party Built-in Apps**</br>&nbsp;&nbsp;&nbsp;&nbsp; 12. Ultra Adware Killer scan</br>&nbsp;&nbsp;&nbsp;&nbsp; 13. MalwareBytes AntiMalware scan</br>&nbsp;&nbsp;&nbsp;&nbsp; 14. Super AntiSpyware scan</br>&nbsp;&nbsp;&nbsp;&nbsp; 15. RogueKiller scan</br>&nbsp;&nbsp;&nbsp;&nbsp; 16. Kaspersky TDSSKiller scan</br>&nbsp;&nbsp;&nbsp;&nbsp; 17. Avast! Browser Cleanup</br>
    - **Reset Actions**</br>&nbsp;&nbsp;&nbsp;&nbsp; 18. Reset the DNS cache</br>&nbsp;&nbsp;&nbsp;&nbsp; 19. Reset the Windows Store</br>&nbsp;&nbsp;&nbsp;&nbsp; 20. Reset all print jobs</br>
    - **Fixes for Common Windows Problems**</br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
      _n/a_</br>
    - **File System Related Actions**</br>&nbsp;&nbsp;&nbsp;&nbsp; 21. Rebuild icon cache</br>
    - **Essential Installes/Updates**</br>&nbsp;&nbsp;&nbsp;&nbsp;
      [<font style="color:ORANGE">If Google Chrome is installed:</font>]</br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; 22. Insall/Update Chrome</br>&nbsp;&nbsp;&nbsp;&nbsp; &nbsp;&nbsp;&nbsp;23. Install uBlock Origin for Chrome</br>&nbsp;&nbsp;&nbsp;&nbsp;
      [<font style="color:ORANGE">If Mozilla Firefox is installed:</font>]</br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; 24. Install/Update Firefox</br>&nbsp;&nbsp;&nbsp;&nbsp; &nbsp;&nbsp;&nbsp;25. Install uBlock Origin for Firefox</br>&nbsp;&nbsp;&nbsp;&nbsp; 26. Install uBlock Origin for Edge</br>&nbsp;&nbsp;&nbsp;&nbsp; 27. PatchMyPC - Update all apps</br>
    - **Privacy Cleanup**</br>&nbsp;&nbsp;&nbsp;&nbsp; 28. Clear all browsers history (all users)</br>&nbsp;&nbsp;&nbsp;&nbsp; 29. Delete browsers cookies (all users)</br>
    - **Maintenance Actions**</br>&nbsp;&nbsp;&nbsp;&nbsp; 30. Empty all users temp folders</br>&nbsp;&nbsp;&nbsp;&nbsp; 31. Empty browsers cache (all users)</br>&nbsp;&nbsp;&nbsp;&nbsp; 32. Unattended disk cleanup</br>
    - **System Repair and Optimization**</br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
      n/a</br>
    - **Windows Troubleshooters**</br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
      n/a</br>
    - **Post-Repair Actions**</br>&nbsp;&nbsp;&nbsp;&nbsp; 33. Restore the previous UAC state</br>&nbsp;&nbsp;&nbsp;&nbsp; 34. Restore previous immunization</br>&nbsp;&nbsp;&nbsp;&nbsp; 35. Delete all restore points (post repair)</br>&nbsp;&nbsp;&nbsp;&nbsp; 36. Create restore point (post repair)</br>&nbsp;&nbsp;&nbsp;&nbsp; 37. Reset power settings</br>&nbsp;&nbsp;&nbsp;&nbsp; 38. Uninstall Malwarebytes Antimalware</br>&nbsp;&nbsp;&nbsp;&nbsp; 39. Uninstall Super AntiSpyware</br>&nbsp;&nbsp;&nbsp;&nbsp; 40. Uinstall RogueKiller</br>&nbsp;&nbsp;&nbsp;&nbsp; 41. Uninstall this application</br>&nbsp;&nbsp;&nbsp;&nbsp; 42. Restore normal boot</br>&nbsp;&nbsp;&nbsp;&nbsp;
  - Select the following loadout settings: _(right menu)_</br>&nbsp;&nbsp;&nbsp;&nbsp; 1. Third party full scans</br>&nbsp;&nbsp;&nbsp;&nbsp; 2. Use unattended mode</br>&nbsp;&nbsp;&nbsp;&nbsp;
  - Click `Run selected fixes/apps`

## Post

- [<font style="color:ORANGE">OPTIONAL</font>] Create a new System Restore point "**COPS - Pre Windows Update**"
- Update Windows (no preview updates)
- Update Apps via Microsoft Store
- Update Apps via Windows Package Manager (winget)
  > _You can queue up multiple commands using PowerShell by pressing `Shift+Enter` to add a new line before pressing `Enter` to executre the commands_
  - winget source update
  - winget upgrade --all --silent
- [<font style="color:ORANGE">OPTIONAL</font>] Create a new System Restore point "**COPS - Pre Driver Update**"
- Update Drivers (SDIO)
- Verify Drivers
  - **Turn On Windows Verifier:**
    - Run `Win+R`: `verifier`
    - Select `Create standard settings`
    - Click `Next`
    - Select `Automatically select all drivers on this computer`
    - Click `Finish`
    - Restart Windows (`shutdown -r -f -t 00`)\
      _Windows Verifier works by stressing out drivers as they're loaded (it is expected that the computer's performance will be impacted while verifier is enabled)_\
      _If Windows loads into the desktop OK and does not crash with verifier enabled, then all is good and you can proceed to turn it off_
  - **Turn Off Windows Verifier:**
    - Run `Win+R`: `verifier`
    - Select `Delete existing settings`
    - Click `Finish`
    - Restart Windows (`shutdown -r -f -t 00`)
- **System Maintenance/Repair**\
  _You can queue up multiple commands using PowerShell by pressing `Shift+Enter` to add a new line before pressing `Enter` to executre the commands_
  ```batch
  winget source reset --force
  winget source update
  winget upgrade --all --silent
  sfc /scannow
  dism /online /cleanup-image /startcomponentcleanup /resetbase
  dism /online /cleanup-image /restorehealth
  sfc /scannow
  defrag /c /o
  chkdsk c: /r /scan /perf
  ```
- Create a new System Restore point "**COPS - Post Virus/Malware Removal**"
