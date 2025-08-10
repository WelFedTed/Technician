<!-- COPS Technician Manual -->

This document is a Work-In-Progress and may contain errors, typo's, etc..\
Please email [shaun@copscorp.com.au](mailto:shaun@copscorp.com.au) with any corrections or to request any additions or changes

<!-- <printfriendly-options style="display:none;" data-content-features="disableClickToDel=0;hideImages=0;imageDisplayStyle=block;disablePDF=0;disableEmail=0;disablePrint=0;encodeImages=0;showHiddenContent=0;"></printfriendly-options><script>var pfBtVersion='3';(function(){var js,pf;pf=document.createElement('script');pf.type='text/javascript';pf.src='//cdn.printfriendly.com/printfriendly.js';document.getElementsByTagName('head')[0].appendChild(pf);})();</script><a href="https://www.printfriendly.com" style="color:#6D9F00;text-decoration:none;" class="printfriendly" onclick="window.print();return false;" title="Printer Friendly and PDF"><img style="border:none;-webkit-box-shadow:none;box-shadow:none;" src="//cdn.printfriendly.com/buttons/new/print-light-blue.svg" alt="Print Friendly and PDF"/></a> -->


# System Service 

<!-- TODO: Download Checklists-->

## Windows <!-- [⬇️](./summaries/system-service_windows.pdf "Download Summary / Checklist") -->

---

### Software

- **Restart Windows**\
  _Force Restart Windows now to provide a clean environment befor proceeding_\
  `shutdown -r -f -t 00`

- **System Restore**\
  - Check System Restore configuration\
    _Make sure System Restore is Enabled on C: and set the allocation to 7%_ 
  - Create a new System Restore point\
    `COPS - Pre System Service`

- **Task Manager**
  - Disable unwanted startup items

- **Wintoys**
  - Install [Wintoys](https://apps.microsoft.com/detail/9p8ltpgcbzxd)\
    `winget install wintoys`\
    or\
    `winget install 9P8LTPGCBZXD`\
    or\
    `ms-windows-store://pdp/?ProductId=9P8LTPGCBZXD`
  - Performance Tab
    - `Ultimate performance power plan`\
      Turn ON if Desktop\
      Turn OFF if Laptop
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
- **Updates**
  - Update Windows\
    _old Windows 10 builds can use the `Windows 10 Update Assistant` to jump to the latest build_
  - Update Apps via `Winget`
  - Update Apps via `Microsoft Store`
  - Update Office Apps\
    `"C:\Program Files\Common Files\microsoft shared\ClickToRun\OfficeC2RClient.exe" /update user forceappshutdown=true`

- **Drivers**
  - Update Drivers using `SDIO`
  - Verify Drivers using `verifier`

- **System Maintenance/Repair**\
  - Open a Terminal as Administrator\
    Run `wt` or `powershell` or `cmd`
  - Run the following commands:\
    `winget source reset --force`\
    `winget source update`\
    `winget upgrade --all --silent`\
    `sfc /scannow`\
    `dism /online /cleanup-image /startcomponentcleanup /resetbase`\
    `dism /online /cleanup-image /restorehealth`\
    `sfc /scannow`\
    `defrag /c /o`\
    `chkdsk c: /r /scan /perf`\
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
  - Create a new System Restore point\
    `COPS - Post System Service`

### Hardware

- Check all buttons and ports are free from debris and working functioning correctly
- Air compress out system as required
- Wipe down device and clean surfaces
- Add a `Serviced by COPS` sticker or replace old worn stickers as required

# Data Transfer

## Windows

---

### Backup

#### Windows

  - Restart Windows\
    _Force Restart Windows now to provide a clean environment befor proceeding_\
    `shutdown -r -f -t 00`
  - [ <font style="color:ORANGE">OPTIONAL</font> ] Create a new System Restore point

#### Antivirus

  - Disable the Antivirus\
    _Some of our extraction tools prompt false positives in the majority of security software_

#### Transfer Drive

  - Create a Job folder on the Transfer Drive
    _naming convention:_\
    `Job#5000`
    - _Create a new folder with the current job number to save User Data to_

#### User Profiles

  - _Copy `C:\Users\` folder to the Job folder on the Transfer Drive_

#### Web Browsers

  For each installed web browser complete the following:

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
      - `edge://sync-internals`\
      - Check Enabled: `Sync Feature Enabled`	= true\
      - Check Account: `Username`\
      - Checked Synced: `Last Synced` = Just now\
      - Check Not Actively Syncing: `Sync Cycle Ongoing` = false\
      - Force Sync (if required): `edge://extensions` - enable `Developer mode` - click `Update`\
    - _AVG Secure Browser:_ `AVG Account`
      <!-- - _TODO (but it's similar to Chrome)_\ -->
    - Mozilla Firefox:_ `Mozilla Account`
      <!-- - _TODO_ -->

#### Programs

  - **Export Installed Programs List**\
    _naming convention:_\
    `Installed Programs - Nirsoft Uninstallview - 2024-07-15.html`\
    or\
    `installed-programs_nirsoft-uninstallview_2024-07-15.html`
    - Use `Nirsoft UninstallView`, save all as `Horizontal HTML`

  - **Export Winget**\
    _naming convention:_\
    `Winget - Export - 2024-07-15.json`\
    or\
    `winget_export_2024-07-15.json`
    - Open a Terminal as Administrator\
      Run `wt` or `powershell` or `cmd`
    - Check Winget is installed `winget -v` (this will throw an error if winget is unavailable)\
    - Update Winget `winget source update`
    - Export Winget's list of installed programs `winget export -o "REPLACE-WITH-TARGET-FILE"`\
    _(update REPLACE-WITH-TARGET-FILE with the target winget export file on the transfer drive)_\
    - Optionally export a list of all programs that Winget does cannot re-install at the same time with this extended command `winget export -o "REPLACE-WITH-TARGET-FILE" >- "winget_unnavailable.txt"`

#### Licenses

  _naming convention:_\
  `License Keys - Nirsoft Product Key Scanner - 2024-07-15.html`\
  or\
  `license-keys_nirsoft-product-key-scanner_2024-07-15.html`
  - _use Nirsoft Product Key Scanner or Nirsoft ProduKey, save all as Horizontal HTML_

#### Emails / Calendars / Contacts

  - Extract Passwords and Server Settings
    - Nirsoft Mail PassView
    - Nirsoft WinMailPassRec
    - Nirsoft PstPassword
  - Backup any accounts set up as POP
    - [_How to export emails to file in Outlook_](https://support.microsoft.com/en-au/office/back-up-your-email-e5845b0b-1aeb-424f-924c-aa1c33b18833)
  - Export Calendars
  - Export Contacts

#### Drivers

  `TRANSFERDRIVE:\\Job#5000\Drivers - 2024-07-15\`\
  or\
  `TRANSFERDRIVER:\\Job#5000\drivers_2024-07-15\`
  - _Open `PowerShell` as an Administrator and run the following script:_\
  `Export-WindowsDriver -Online -Destination "REPLACE-WITH-TARGET-FOLDER"`\
  _(update REPLACE-WITH-TARGET-FOLDER with the target drivers folder on the transfer drive)_

#### Other

  - **Check C: Drive for unusual files/folders**
    - _copy to Job folder copying the C: Drive file structure (TransferDrive:\\Job\#5000\\C\\FolderToSave)_
  - [ <font style="color:ORANGE">OPTIONAL</font> ] Create Winget Install Script
    - _https://winstall.app/ - Select Desired Programs - Generate Script - Download both Batch (.bat) and PowerShell (.ps1) scripts_

### Prepare New Device _(if required)_

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
    - [ <font style="color:ORANGE">OPTIONAL</font> ] Switch Out of S Mode\
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
  - Open Windows Update\
    Run `control update`
  - Click `Resume updates` if updates are currently paused
  - Disable `Get the latest updates as soon as they're available`
  - Advanced options
    - Enable `Receive update for other Microsoft products`
    - Disable `Get me up to date`
    - Enable `Notify me when a restart is required to finish updating`
    - Delivery Optimization
      - Enable `Allow downloads from other devices`
        - Select `Devices on my local network`
- **Update Microsoft Store Apps**\
  - Open Microsoft Store\
    Run `ms-windows-store:`
    - Click `Downloads`
    - Click `Check for updates`
    - Click `Update all`
- **Update Winget Apps**\
  - Open a Terminal\
    Run `wt` or `powershell` or `cmd`
  - Run the following commands:\
    `winget source update`\
    `winget upgrade --all --silent`\
- **Update Windows**\
  `control update`
- **Update Office apps**\
  - Run `"C:\Program Files\Common Files\microsoft shared\ClickToRun\OfficeC2RClient.exe" /update user forceappshutdown=true`
- **Check Drivers**\
  Bangs(!) exclamation marks in Device Manager indicates missing, incorrect, or corrupt drivers
  - Open `Device Manager` to check for Bangs(!)
  - Run `Snappy Driver Installer Origin (SDIO)` as an Administrator
  - Select `TODO: Create a new system restore point`
  - Select all missing/incorrect/corrupt drivers (as per bangs! in Device Manager)
  - Click `Install`
- **[ <font style="color:ORANGE">OPTIONAL</font> ] Update Outdated Drivers**
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

### Restore

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
  - Run `netplwiz` - Select `COPS` - Click `Remove`
  - Delete `C:\Users\COPS\` folder\
  _Windows may prevent you from removing this folder if it's currently accessing it in the background, if this happens just restart Windows and try to remove it again_
  - Empty Recycle Bin
- **System Maintenance/Repair**\
  - Open a Terminal as Administrator\
    Run `wt` or `powershell` or `cmd`
  - Run the following commands:\
    `winget source reset --force`\
    `winget source update`\
    `winget upgrade --all --silent`\
    `sfc /scannow`\
    `dism /online /cleanup-image /startcomponentcleanup /resetbase`\
    `dism /online /cleanup-image /restorehealth`\
    `sfc /scannow`\
    `defrag /c /o`\
    `chkdsk c: /r /scan /perf`\
    <details>
      <summary>Useful Tip</summary>
      You can queue up multiple commands in PowerShell by pressing `Shift+Enter` to add a new line before pressing `Enter` to execute the all of the queued up commands one after another
  </details>
- **Restart Windows**
- **Create a new System Restore point** `COPS - Completed Data Transfer`



# Virus/Malware Removal

## Windows

---

<!--
    TO DO:
    - fill out large tasks sub-tasks (revo, cleanmgr, uvk, verifier, etc..)
    - document more comprehensively with tooltips and/or images
    - mouse over tool tips
        [Display text](## "Hover text")
    - implement coloured text and improved document formatting
    - make markdown doc work with a technician wiki? (Obsidian knowledgebase?)
-->

### Pre Scans

- [ <font style="color:RED">**IMPORTANT**</font> ] **Air Gap Device**\
  _Ensure device is disconnected from all networks before RKill is run successfully and RATs ( Remote Access Tools ) removed, to ensure malicious actors do not re-connect to the device while it's still compromised_
- Enable System Restore (set to 7% allocation if enough free disk space)
- [ <font style="color:ORANGE">OPTIONAL</font> ] **Create a new [System Restore](https://support.microsoft.com/en-gb/windows/create-a-system-restore-point-77e02e2a-3298-c869-9974-ef5658ea3be9) point**\
  `COPS - Pre Virus/Malware Removal`\
  _This System Restore point will be wiped out in a later step (post-virus/malware removal), as malware can persist in old System Restore points_
- **Restart Windows**\
  _Force Restart Windows now to provide a clean environment befor proceeding_\
  `shutdown -r -f -t 00`
- **COPS Folder**\
  Create `C:\COPS\` folder on the system
  - [ <font style="color:ORANGE">OPTIONAL</font> ] Add `C:\COPS\` to the installed antivirus's exclusion list\
    [Trend Micro](https://helpcenter.trendmicro.com/en-us/article/tmka-14498 "How to add an exclusion to Trend Micro")\
    [Windows Security](https://support.microsoft.com/en-au/windows/add-an-exclusion-to-windows-security-811816c0-4dfd-af4a-47e4-c301afe13b26 "How to add an exclusion to Windows Security")\
- **Disable Antivirus**\
  [Trend Micro](https://helpcenter.trendmicro.com/en-us/article/tmka-10319 "How to disable Trend Micro")\
  [Windows Security](https://support.microsoft.com/en-au/windows/virus-and-threat-protection-in-the-windows-security-app-1362f4cd-d71a-b52a-0b66-c2820032b65e "How to disable Windows Security")\
- **RKill**
  - Copy `RKill` folder from your USB Tool to the `COPS` folder\
    RKill can't run from a write-blocked drive, so you'll usually need to copy the executables out first
  - [ <font style="color:RED">**IMPORTANT**</font> ] Run any RKill executable as Admininstrator
  - Wait for RKill to complete, it will then generate a report `RKill.txt` on the current user's desktop
  - Move `RKill.txt` from `%USERPROFILE%\Desktop` to `COPS` folder
- **Revo Uninstaller**
  <!-- TODO: add revo instructions -->
- **Disk Cleanup**
  - Run `cleanmgr /sageset:10`\
    _This will open the Disk Cleanup utility to create settings for Profile 10_
  - Click `Clean up system files`
  - Select all checkboxes except for the following system error options:\
    `System error memory dump files`\
    `System error minidump files`\
    <details>
      <summary>Useful Tip</summary>
    You can click on an option, and then use the `UP` + `DOWN` arrows + `Space Bar` to quickly check or uncheck options
    </details>
  - Click `OK`
  - Run `cleanmgr /sagerun:10`\
    _This will run the Disk Cleanup utility to using Profile 10's settings_

### Scans

- Connect to Internet
- [ <font style="color:ORANGE">OPTIONAL</font> ] [AdwCleaner](https://www.malwarebytes.com/adwcleaner)\
  _AdwCleaner crashes out of UVK's automation, so run it now instead if you want to use it_
- [ <font style="color:ORANGE">OPTIONAL</font> ] [Spybot - Search & Destroy](https://www.safer-networking.org/free-download/)\
  _Spybot is a thorough malware removal tool, but it can take a very long time to complete it's scans_
- [ <font style="color:ORANGE">OPTIONAL</font> ] [Windows Defender Offline Scan](https://support.microsoft.com/en-au/windows/help-protect-my-pc-with-microsoft-defender-offline-9306d528-64bf-4668-5b80-ff533f183d6c "How to use Windows Defender Offline")
- [ <font style="color:ORANGE">OPTIONAL</font> ] Create a new System Restore point `COPS - Pre Virus/Malware Removal`
- [Ultra Virus Killer (UVK)](https://www.carifred.com/uvk/)
  - Install UVK
  - Open UVK
    - Do <u>not</u> disable Hybrid Shutdown if asked when opening UVK
    - Do Update UVK if asked when opening UVK
  - Click System Repair
  - Select the following repair actions: _(left menu)_
    <details>
      <summary>Useful Tip</summary>
    You can click on an option, and then use the `UP` + `DOWN` arrows + `Space Bar` to quickly check or uncheck options
    </details>
    - **Pre-Repair Actions**</br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;1. Set technician power settings</br>&nbsp;&nbsp;&nbsp;&nbsp; 2. Kill all non system processes</br>&nbsp;&nbsp;&nbsp;&nbsp; 3. Delete all restore points</br>&nbsp;&nbsp;&nbsp;&nbsp; 4. Create a system restore point</br>&nbsp;&nbsp;&nbsp;&nbsp; 5. Free physical memory</br>&nbsp;&nbsp;&nbsp;&nbsp; 6. Backup the registry</br>&nbsp;&nbsp;&nbsp;&nbsp; 7. Un-immunize all areas</br>&nbsp;&nbsp;&nbsp;&nbsp; 8. Disable the User Account Control</br>&nbsp;&nbsp;&nbsp;&nbsp; 9. Enable the legacy (F8) boot menu</br>&nbsp;&nbsp;&nbsp;&nbsp; 10. Enable Windows Recovery Environment</br>&nbsp;&nbsp;&nbsp;&nbsp; 11. Prevent rebooting until all is done</br>
    - **Third-Party Built-in Apps**</br>&nbsp;&nbsp;&nbsp;&nbsp; 12. Ultra Adware Killer scan</br>&nbsp;&nbsp;&nbsp;&nbsp; 13. MalwareBytes AntiMalware scan</br>&nbsp;&nbsp;&nbsp;&nbsp; 14. Super AntiSpyware scan</br>&nbsp;&nbsp;&nbsp;&nbsp; 15. RogueKiller scan</br>&nbsp;&nbsp;&nbsp;&nbsp; 16. Kaspersky TDSSKiller scan</br>&nbsp;&nbsp;&nbsp;&nbsp; 17. Avast! Browser Cleanup</br>
    - **Reset Actions**</br>&nbsp;&nbsp;&nbsp;&nbsp; 18. Reset the DNS cache</br>&nbsp;&nbsp;&nbsp;&nbsp; 19. Reset the Windows Store</br>&nbsp;&nbsp;&nbsp;&nbsp; 20. Reset all print jobs</br>
    - **Fixes for Common Windows Problems**</br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
      _n/a_</br>
    - **File System Related Actions**</br>&nbsp;&nbsp;&nbsp;&nbsp; 21. Rebuild icon cache</br>
    - **Essential Installes/Updates**</br>&nbsp;&nbsp;&nbsp;&nbsp;
      [ <font style="color:ORANGE">If Google Chrome is installed</font> ]</br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; 22. Insall/Update Chrome</br>&nbsp;&nbsp;&nbsp;&nbsp; &nbsp;&nbsp;&nbsp;23. Install uBlock Origin for Chrome</br>&nbsp;&nbsp;&nbsp;&nbsp;
      [ <font style="color:ORANGE">If Mozilla Firefox is installed</font> ]</br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; 24. Install/Update Firefox</br>&nbsp;&nbsp;&nbsp;&nbsp; &nbsp;&nbsp;&nbsp;25. Install uBlock Origin for Firefox</br>&nbsp;&nbsp;&nbsp;&nbsp; 26. Install uBlock Origin for Edge</br>&nbsp;&nbsp;&nbsp;&nbsp; 27. PatchMyPC - Update all apps</br>
    - **Privacy Cleanup**</br>&nbsp;&nbsp;&nbsp;&nbsp; 28. Clear all browsers history (all users)</br>&nbsp;&nbsp;&nbsp;&nbsp; 29. Delete browsers cookies (all users)</br>
    - **Maintenance Actions**</br>&nbsp;&nbsp;&nbsp;&nbsp; 30. Empty all users temp folders</br>&nbsp;&nbsp;&nbsp;&nbsp; 31. Empty browsers cache (all users)</br>&nbsp;&nbsp;&nbsp;&nbsp; 32. Unattended disk cleanup</br>
    - **System Repair and Optimization**</br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
      n/a</br>
    - **Windows Troubleshooters**</br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
      n/a</br>
    - **Post-Repair Actions**</br>&nbsp;&nbsp;&nbsp;&nbsp; 33. Restore the previous UAC state</br>&nbsp;&nbsp;&nbsp;&nbsp; 34. Restore previous immunization</br>&nbsp;&nbsp;&nbsp;&nbsp; 35. Delete all restore points (post repair)</br>&nbsp;&nbsp;&nbsp;&nbsp; 36. Create restore point (post repair)</br>&nbsp;&nbsp;&nbsp;&nbsp; 37. Reset power settings</br>&nbsp;&nbsp;&nbsp;&nbsp; 38. Uninstall Malwarebytes Antimalware</br>&nbsp;&nbsp;&nbsp;&nbsp; 39. Uninstall Super AntiSpyware</br>&nbsp;&nbsp;&nbsp;&nbsp; 40. Uinstall RogueKiller</br>&nbsp;&nbsp;&nbsp;&nbsp; 41. Uninstall this application</br>&nbsp;&nbsp;&nbsp;&nbsp; 42. Restore normal boot</br>&nbsp;&nbsp;&nbsp;&nbsp;
  - Select the following loadout settings: _(right menu)_</br>&nbsp;&nbsp;&nbsp;&nbsp; 1. Third party full scans</br>&nbsp;&nbsp;&nbsp;&nbsp; 2. Use unattended mode</br>&nbsp;&nbsp;&nbsp;&nbsp;
  - Click `Run selected fixes/apps`

### Post Scans

- [ <font style="color:ORANGE">OPTIONAL</font> ] Create a new System Restore point `COPS - Pre Windows Update`
- Update Windows (no preview updates)
- Update Apps via Microsoft Store
- Update Apps via Windows Package Manager (winget)\
  `winget source update`\
  `winget upgrade --all --silent`\
  <details>
    <summary>Useful Tip</summary>
    You can queue up multiple commands in PowerShell by pressing `Shift+Enter` to add a new line before pressing `Enter` to execute the all of the queued up commands one after another
  </details>
- [ <font style="color:ORANGE">OPTIONAL</font> ] Create a new System Restore point `COPS - Pre Driver Update`
- Update Drivers (SDIO)
- Verify Drivers
  - **Turn On Windows Verifier:**
    - Run `verifier`
    - Select `Create standard settings`
    - Click `Next`
    - Select `Automatically select all drivers on this computer`
    - Click `Finish`
    - Restart Windows (`shutdown -r -f -t 00`)\
      _Windows Verifier works by stressing out drivers as they're loaded (it is expected that the computer's performance will be impacted while verifier is enabled)_\
      _If Windows loads into the desktop OK and does not crash with verifier enabled, then all is good and you can proceed to turn it off_
  - **Turn Off Windows Verifier:**
    - Run `verifier`
    - Select `Delete existing settings`
    - Click `Finish`
    - Restart Windows\
      `shutdown -r -f -t 00`
- **System Maintenance/Repair**\
  - Open a Terminal as Administrator\
    Run `wt` or `powershell` or `cmd`
  - Run the following commands:\
    `winget source reset --force`\
    `winget source update`\
    `winget upgrade --all --silent`\
    `sfc /scannow`\
    `dism /online /cleanup-image /startcomponentcleanup /resetbase`\
    `dism /online /cleanup-image /restorehealth`\
    `sfc /scannow`\
    `defrag /c /o`\
    `chkdsk c: /r /scan /perf`\
    <details>
      <summary>Useful Tip</summary>
      You can queue up multiple commands in PowerShell by pressing `Shift+Enter` to add a new line before pressing `Enter` to execute the all of the queued up commands one after another
    </details>
- Create a new System Restore point `COPS - Post Virus/Malware Removal`

## Android

---

### Pre Scans

- **Remove Intrusive Full-Screen Pop-Ups**\
  These relentless pop-ups make the device impossible to work with, so deal with these first _(if applicable)_\
  <details>
    <summary>More Info</summary>
    These full screen pop-ups/ads aren't a sign of an injection, but merely a malicious use of the native Android notification system.\
    Users don't intentionally give these apps permission to do this, but it's often caused by [Tapjacking](https://developer.android.com/privacy-and-security/risks/tapjacking) or simply users ignorantly agreeing to permission prompts.
  </details>
  - Open `Play Store`
    - Install [Ad Virus Cleaner - ROX Security](https://play.google.com/store/apps/details?id=com.tafayor.roxapp&pcampaignid=web_share "ROX Security app")
  - Open `ROX Security` <!-- TODO: verify steps are correct and spelt correctly -->
    - Tap `Scan`
    - Wait for the scan to complete
    - Tap on `Pop-up Ad Detector`
      - Tap on `Give Permissions`\
        This will open a required permissions settings panel
        - Enable `ROX Security`
        - Tap `<` _(back button)_
    - Wait for an intrusive full-screen pop-up
    - Tap `|||` _(app switch button)_
      - Switch back to `Rox Security`
        `Rox Security` should have logged recent app activity under it's `Pop-up Ad Detector`
    - Tap `:` _(kebab button)_ next to the offending app
      - Tap `Show in Play Store`
      - Verify the app is not important\
        _If the app is published by Google or the device's manufacturer (i.e. Samsung) think twice before removing_
      - Tap `Uninstall`
  - Uninstall `ROX Security` when done
- **Safe Mode**\
  Reboot the device in Safe-Mode _(if available)_
- **Malicious or Suspicious Apps**\
  - Remove any remote access apps _(i.e. AnyDesk, TeamViewer, etc..)_\
    _These are used by scammers to access devices remotely_
  - Remove any malicious or bloatware apps\
    _The following are common types of apps that are unnecessary often load their own malware_
    - Any free 3rd-party "Cleaner" apps
    - Any free 3rd-party "QR Scanner" apps
    - Any free 3rd-party "PDF Reader" apps _(excluding [Adobe Acrobat Reader](https://play.google.com/store/apps/details?id=com.adobe.reader&hl=en))_
    - Any free 3rd-party "File Manager" apps
  - Remove any "Crypto" apps _(after verifying the customer does not genuinely use them)_\
    _Scammers often load on crypto apps to try and steal currencies the device has access to_
- **Web Browsers**\
  Clear Cache + Data for all Web Browsers installed on the device.\
  _The following steps are for Google Chrome, but other apps are managed that same way_
  - Open `Settings`
    - Tap `Apps` <!-- TODO: verify steps are correct and spelt correctly -->
      - Tap `Chrome`
        - Tap `Storage`
          - Tap `Clear cache`
          - Tap `Clear data`

### 1st Party Scans

- `Play Protect` Scan
- [ <font style="color:ORANGE">If Samsung Device</font> ]
  - Samsung `Device Care` Scan

### 3rd Party Scans

- Install and Run <u>at least 3</u> of the following free malware scanners:
  - [Malwarebytes Mobile Security](https://play.google.com/store/apps/details?id=org.malwarebytes.antimalware&hl=en_AU)
  - [AVG AntiVirus & Security](https://play.google.com/store/apps/details?id=com.antivirus&hl=en_AU)
  - [Bitdefender Antivirus](https://play.google.com/store/apps/details?id=com.bitdefender.antivirus&hl=en_AU)
  - [Sophos Intercept X for Mobile](https://play.google.com/store/apps/details?id=com.sophos.smsec&hl=en_AU)
  - [Avira Security Antivirus & VPN](https://play.google.com/store/apps/details?id=com.avira.android&hl=en_AU)
  - [Trend Micro Mobile Security & Antivirus](https://play.google.com/store/apps/details?id=com.trendmicro.tmmspersonal&hl=en_AU)
  - [ESET Mobile Security Antivirus](https://play.google.com/store/apps/details?id=com.eset.ems2.gp&hl=en_AU)
  - [TotalAV Mobile Security](https://play.google.com/store/apps/details?id=com.totalav.android&hl=en_AU) _untested if can be used without an account_
  - [Panda Dome Antivirus and VPN](https://play.google.com/store/apps/details?id=com.pandasecurity.pandaav&hl=en_AU) _untested if can be used without an account_
  - [Avast Antivirus & Security](https://play.google.com/store/apps/details?id=com.avast.android.mobilesecurity&hl=en_AU) _untested if can be used without an account_

### Updates

- Update Apps via `Play Store`
- [ <font style="color:ORANGE">If Samsung Device</font> ]
  - Update Apps via `Galaxy Store`
- Update `Android OS`\
  This may take multiple updates and reboots, as customers often neglect updating their devices


# Backup / Export

## Windows

---

## macOS

---

### Backup Device

- Use Time Machine

## iOS

---

### Export Messages

- [imessage-exporter](https://github.com/ReagentX/imessage-exporter)

### Export Photos

<!-- reference: https://support.apple.com/en-au/guide/image-capture/imgcp1003/mac -->
- Connect the iOS device to a macOS device\
  You may need to unlock the iOS device and tap `Trust` if prompted
- Open `Image Capture` app
- Click on the iOS device\
  The connected iOS device should show up under `DEVICES` on the left
- Change `Import To:` folder\
  Make a Job# folder to import the photos/videos to
- Click `Download All`

### Backup iCloud Photos <!-- TODO: check this is accurate -->

- Submit `Apple Privacy Data Request`
  - Sign in [Apple's Data and Privacy page](https://privacy.apple.com/) with the customer's `Apple Account`
  - Click `Request a copy of your data`
  - Tick `iCloud Photos`
  - Click `Continue`
  - Choose the largest bundle/zip size _(this will make downloading the files easier, as you can only download 3 of the part files at a time)_
- Check confirmation email\
  Apple will send a confirmation email to the customer's Apple Account email address, if this does not come through now then you may have issues receiving the download link email later
- Wait for the download link email\
  Apple will have to compile and zip up all of the data you requested, this can take many days
- Open download link
- Download all .zip files Apple prepared for download
- Unzip all .zip files
- Combine the unzipped data in to one folder

## Android

---


# OS Install Media Creation

## Windows <!-- TODO: flesh this out -->

---

### Download

- Download from [massgrave.dev](https://massgrave.dev/genuine-installation-media)

### Verify

- Verify checksums against [rg-adguard.net](https://files.rg-adguard.net/)

### Flash

- Flash image to USB using [Rufus](https://rufus.ie/en/)\
  `winget install rufus.rufus`

### Inject Drivers

- **Prep**
  - Have a folder with extracted drivers ready to go\
    `C:\drivers\` for this example
  - Create an empty directory ready to mount the Windows image to for editing\
    `C:\mount\` for this example
  - Have a Windows image ready to go\
    `F:\sources\install.wim` for this example

- **Mount**
  - Open Powershell as admin
  - Find index of the Windows image you want to mount\
    `Get-WindowsImage -ImagePath F:\sources\install.wim`
  - Mount the Windows image\
    `Mount-WindowsImage -Path C:\mount\ -ImagePath F:\sources\install.wim -Index 1`

- **Add Drivers**
  - `Add-WindowsDriver -Path C:\mount\ -Driver C:\drivers\ -Recurse -ForceUnsigned`

- **Unmount**
  - `Dismount-WindowsImage -Path C:\mount\ –Save`

# Sideloading <!-- TODO: flesh this out -->

## Android

---

### Download

- Download desired .APK from 3rd party source or directly from the `Google Play` store using [Aurora Store](https://auroraoss.com/)
- [ <font style="color:ORANGE">If you can only download an App Bundle (.APKS, .XAPK, .APKM)</font> ]
  - Use [AntiSplit M](https://github.com/AbdurazaaqMohammed/AntiSplit-M) to merge the bundle components back in to a .APK file

<!-- notes from reddit (https://www.reddit.com/r/degoogle/comments/1bf4hwv/how_do_i_get_apks_from_aurora_store/)
  - Install the app you want the APK of via the Aurora Store. You don't need to run the app or give it any permissions.

  - Go back to your Aurora main screen and tap the downloads icon in the upper right corner.

  Find the app you just installed at the top of the list. Tap and hold on it. Select "Save App bundle". Save it somewhere. It will give you a ZIP file.

  - Download AntiSplit-M and install it.

  - Run AntiSplit-M and tap "Select split APK to Merge". Select the ZIP file you saved above.

  - Save the APK somewhere.

  - It runs for a few seconds.

  - You now have an APK. Do APK things with it.
 -->

### Upload

- Connect the Android device to a computer
- Navigate to it's mounted file system _(i.e. in `This PC`)_
- Open `Downloads` folder
- Copy `.APK` file in to the `Downloads` folder

### Install

- Enable Sideloading\
  _Depending on the manufacturer of the device, you may need to enable Sideloading before you can install .APK files_\
  [Samsung](https://www.samsung.com/ae/support/mobile-devices/how-to-enable-permission-to-install-apps-from-unknown-source-on-my-samsung-phone/ "How to enable sideloading on Samsung devices")
- Open `Files` app
- Navigate to `Downloads` folder
- Tap on the `.APK` file
- Tap `Install`

# USB Tool <!-- TODO: flesh this out -->

## Ventoy

## Medicat

## Bootable Tools

## Windows Tools

## COPS Extras (scripts, etc..)

# Reference

## Apps

---

### Windows

| App | Install | Description | Use Case |
| :-- | :-- | :-- | :-- |
| [AMD Adrenalin](https://www.amd.com/en/products/software/adrenalin.html) ||||
| [Apple iTunes](https://www.apple.com/au/itunes/) | `winget install Apple.iTunes` || <u>DEPRECATED</U></br>Use `Apple Devices` instead |
| [Apple Devices](https://support.apple.com/en-au/guide/devices-windows/mchl5ded2763/windows) | `winget install "Apple Devices"` |||
| [Clear Disk Info](https://www.carifred.com/cleardiskinfo/) | `winget install Carifred.ClearDiskInfo` |||
| [CPUID CPU-Z](https://www.cpuid.com/softwares/cpu-z.html) | `winget install CPUID.CPU-Z` |||
| [CPUID HWMonitor](https://www.cpuid.com/softwares/hwmonitor.html) | `winget install CPUID.HWMonitor` |||
| [CrystalDiskInfo](https://crystalmark.info/en/software/crystaldiskinfo/) | `winget install CrystalDewWorld.CrystalDiskInfo` || <u>DEPRACATED</u></br>Misreports SMART data on some drives, use `Clear Disk Info` instead |
| [CrystalDiskMark](https://crystalmark.info/en/software/crystaldiskmark/) | `winget install CrystalDewWorld.CrystalDiskMark` |||
| [Display Driver Uninstaller (DDU)](https://www.guru3d.com/download/display-driver-uninstaller-download/) | `winget install Wagnardsoft.DisplayDriverUninstaller` |||
| [FileZilla](https://filezilla-project.org/) ||||
| [ForensiT Transwiz](https://www.forensit.com/move-computer.html) | `winget install ForensiT.Transwiz` || <u>DEPRECATED</u></br>Breaks with newer OneDrive and Windows 11 releases, manually copy %USERPROFILE% instead |
| [Furmark](https://www.geeks3d.com/furmark/) | `winget install Geeks3D.FurMark.2` |||
| [GPU-Z](https://www.techpowerup.com/download/techpowerup-gpu-z/) | `winget install TechPowerUp.GPU-Z` |||
| [Intel HD Graphics](https://www.intel.com/content/www/us/en/support/products/80939/graphics.html) ||||
| [Libre Office](https://www.libreoffice.org/) | `winget install TheDocumentFoundation.LibreOffice` |||
| [Microsoft Office](https://www.microsoft.com/en-au/microsoft-365/microsoft-office) | `winget install Microsoft.Office` |||
| [Microsoft PC Health Check](https://support.microsoft.com/en-au/windows/how-to-use-the-pc-health-check-app-9c8abd9b-03ba-4e67-81ef-36f37caa7844) | `winget install Microsoft.WindowsPCHealthCheck` |||
| [Microsoft Visual Studio Code](https://code.visualstudio.com/) | `winget install Microsoft.VisualStudioCode` ||
| [Microsoft Windows Terminal](https://github.com/microsoft/terminal) | `winget install Microsoft.WindowsTerminal` |||
| [Microsoft Verifier](https://learn.microsoft.com/en-us/windows-hardware/drivers/devtest/driver-verifier) ||||
| [MiniTool Partition Wizard](https://www.partitionwizard.com/) | `winget install MiniTool.PartitionWizard.Free` |||
| [NirSoft BlueScreenView](https://www.nirsoft.net/utils/blue_screen_view.html) | `winget install NirSoft.BlueScreenView` |||
| [NirSoft Product Key Scanner](https://www.nirsoft.net/utils/product_key_scanner.html) ||||
| [NirSoft ProduKey](https://www.nirsoft.net/utils/product_cd_key_viewer.html) ||||
| [Nvidia App](https://www.nvidia.com/en-au/software/nvidia-app/) ||||
| [RevoUninstaller](https://www.revouninstaller.com/) | `winget install RevoUninstaller.RevoUninstaller` |||
| [Snappy Driver Installer Origin (SDIO)](https://www.glenn.delahoy.com/snappy-driver-installer-origin/) | `winget install GlennDelahoy.SnappyDriverInstallerOrigin` |||
| [Sublime Text](https://www.sublimetext.com/) | `winget install SublimeHQ.SublimeText.4` |||
| [TeamViewer](https://www.teamviewer.com/en-au/) | `winget install TeamViewer.TeamViewer` |||
| [UltraViewer](https://www.ultraviewer.net/en/) | `winget install DucFabulous.UltraViewer` |||
| [Ultra Virus Killer (UVK)](https://www.carifred.com/uvk/) ||||
| Google Chrome | `winget install Google.Chrome` |||
| Mozilla Firefox | `winget install Mozilla.Firefox` |||
| Mozilla Thunderbird | `winget install Mozilla.Thunderbird` |||
| eM Client | `winget install eMClient.eMClient` |||
| Disk Drill | `winget install CleverFiles.DiskDrill` |||
| HWiNFO | `winget install REALiX.HWiNFO` |||
| Cinebench | `winget install Maxon.CinebenchR23` |||
| VLC | `winget install VideoLAN.VLC` |||
| GitHub Desktop | `winget install GitHub.GitHubDesktop` |||
| Trend Micro Internet Security | `winget install "Trend Micro Internet Security"` |||
| Trend Micro Maximum Security | `winget install "Trend Micro Maximum Security"` |||
| HashCheck Shell Extension | `winget install idrassi.HashCheckShellExtension` |||
| Git | `winget install Git.Git` |||
| [MakeMKV](https://www.makemkv.com/) | `winget install GuinpinSoft.MakeMKV`<hr>[public beta key](https://forum.makemkv.com/forum/viewtopic.php?f=5&t=1053) |||
| [HD Tune Pro](https://www.hdtune.com/index.html) | `winget install EFDSoftware.HDTunePro` | HDD / SSD Utility | Benchmark drive speed over time with graph |
| 7-Zip ||||
| AltSnap ||||
| BandiZip ||||
| BandiView ||||
| Bitwarden ||||
| Winget ||||
| Chocolatey ||||
| FFmpeg ||||
| FileBot ||||
| HandBrake ||||
| iPerf ||||
| JDownloader ||||
| HexChat ||||
| qBittorrent ||||
| MediaInfo ||||
| Microsoft OneDrive ||||
| Google Drive ||||
| DropBox ||||
| NVIDIA GeForce Experience ||| <u>DEPRECATED</u></br>Use `NVIDIA App` instead |
| Papa's Best STL Viewer ||||
| PowerToys ||||
| Proton VPN ||||
| ReNamer ||||
| Rufus ||||
| BalenaEtcher ||||
| SD Card Formatter ||||
| [Raspberry Pi Imager](https://www.raspberrypi.com/software/) ||||
| WinRAR ||||
| [Win32 Disk Imager](https://sourceforge.net/projects/win32diskimager/) ||||
| WizTree ||||
| Everything ||||
| [yt-dlp](https://github.com/yt-dlp/yt-dlp) | `winget install yt-dlp.yt-dlp` |||
| Audacity ||||
| [Exact Audio Copy (EAC)](https://www.exactaudiocopy.de/) ||||
| OpenOffice ||||
| Inkscape | `winget install Inkscape.Inkscape` |||
| Intel PresentMon ||||
| [Chocolatey](https://chocolatey.org/) || Alternative Windows package manager ||
| [Scoop](https://scoop.sh/) || Alternative Windows package manager ||
| [iMazing Converter](https://imazing.com/converter) | `winget install DigiDNA.iMazingHEICConverter`|||
| [iMazing](https://imazing.com/) | `winget install DigiDNA.iMazing` |||
<!-- TODO: finish this table -->

### macOS

| App | Install | Description | Use Case |
| :-- | :--     | :--         | :--      |
| [Apple Image Capture](https://support.apple.com/en-au/guide/image-capture/welcome/mac) || Download photos/videos from digital cameras or iOS devices | Useful for backing up photos/videos from iOS devices, even if their iCloud account isn't working, as it treats the iOS device like a digital camera and simply imports the local copies on the device |
| Microsoft Remote Desktop ||| <u>DEPRECATED</u></br>Use `Microsoft Windows App` instead |
| Microsoft Windows App ||||

### iOS

### Android

| App   | Description   | Use Case  |
| :---  | :---          | :---      |
| [Appwatch](https://play.google.com/store/apps/details?id=com.tafayor.appwatch&hl=en_AU) | Snitch on app activity | <u>DEPRECATED</u></br>Use `Rox Security` instead<hr>_Identify apps that are responsible for instrusive full-screen pop-ups_ |
| [Aurora Store](https://auroraoss.com/aurora-store) | Alternative `Google Play Store` app | Install apps from the Play Store repository without needing to log in with a Google Account, and can download .APKs from the Play Store for later sideloading |
| [Rox Security](https://play.google.com/store/apps/details?id=com.tafayor.roxapp&hl=en_AU&pli=1) | Multi-tool for identifying unusual/unwanted app behaviour, including snitching on app activity | Identify apps that are responsible for instrusive full-screen pop-ups |

## Commands

---

### Windows

| Command                   | Description                                         | Use Case  |
| :---                      | :---                                                | :---      |
| `\`                       | Opens `%SYSTEMDRIVE%` folder                        | Quick access to `C:\` |
| `appwiz.cpl`              | Opens `Programs and Features` control panel window  ||
| `calc`                    | Opens `Calculator` app ||
| `charmap`                 | Opens `Character Map` app ||
| `chrome`                  | Opens `Google Chrome` app _(if installed)_ ||
| `cmd`                     | Opens `Command Prompt` app _(if installed)_ ||
| `code`                    | Opens `Visual Studio Code` app ||
| `compmgmt.msc`            | Opens `Computer Management` snap in ||
| `control`                 | Opens `Control Panel` ||
| `control folders`         | Opens `File Explorer Options` window ||
| `control keyboard`        | Opens `Keyboard Properties` window ||
| `control printers`        | Opens `Bluetooth & devices` settings window         | Quick access to `Printers & scanners` |
| `control update`          | Opens `Windows Update` settings window              ||
| `desk.cpl`                | Opens `Display` settings window ||
| `devmgmt.msc`             | Opens `Device Manager` snap in                      ||
| `diskmgmt.msc`            | Opens `Disk Management` snap in ||
| `diskpart`                | Opens `Microsoft DiskPart` command line interface ||
| `documents`               | Opens current user's `Documents` folder ||
| `downloads`               | Opens current user's `Downloads` folder ||
| `dxdiag`                  | Opens `DirectX Diagnostic Tool` app ||
| `eventvwr.msc`            | Opens `Event Viewer` snap in ||
| `explorer`                | Opens `Windows Explorer` ||
| `firefox`                 | Opens `Mozilla Firefox` app _(if installed)_ ||
| `firewall.cpl`            | Opens `Windows Defender Firewall` control panel window ||
| `fonts`                   | Opens `Fonts` folder ||
| `gpedit.msc`              | Opens `Local Group Policy Editor` snap in ||
| `iexplore`                | Opens `Internet Explorer` app ||
| `inetcpl.cpl`             | Opens `Internet Properties` window                  | Quick access to `Proxy server` settings |
| `joy.cpl`                 | Opens `Game Controllers` window                     | Use to test game controller inputs |
| `lusrmgr.msc`             | Opens `Local Users and Groups` snap in              | Powerful control over User Accounts and Groups, but does <u>not</u> work on Windows Home editions |
| `main.cpl`                | Opens `Mouse Properties` window ||
| `manage-bde c: -off`      | Run in a terminal to decrypt and disable `BitLocker` on C: drive ||
| `manage-bde -status`      | Run in a terminal to show `BitLocker` status of all drives ||
| `mdsched`                 | Opens `Windows Memory Diagnostic` app ||
| `mmc`                     | Opens empty `Microsoft Management Console` snap in  ||
| `mmsys.cpl`               | Opens `Sound` window ||
| `mrt`                     | Opens `Microsoft Windows Malicious Software Removal Tool` app ||
| `msconfig`                | Opens `System Configuration` window                 | Quick access to `Safe boot` or Windows boot entries |
| `msedge`                  | Opens `Microsoft Edge` app ||
| `msinfo32`                | Opens `System Information` ||
| `mstsc`                   | Opens `Remote Desktop Connection` app ||
| `ms-windows-store:`       | Opens `Microsoft Store` app                         ||
| `ncpa.cpl`                | Opens `Network Connections` control panel window    ||
| `netplwiz`                | Opens `User Accounts` window                        | Less powerful control over User Accounts, but does work on Windows Home editions |
| `notepad`                 | Opens `Notepad` app                                 ||
| `onedrive`                | Opens current user's `OneDrive` folder ||
| `osk`                     | Opens `On-Screen Keyboard` ||
| `pictures`                | Opens current user's `Pictures` folder ||
| `powercfg.cpl`            | Opens `Power Options` control panel window          ||
| `powershell`              | Opens `Powershell` app ||
| `regedit`                 | Opens `Registry Editor` app ||
| `resmon`                  | Opens `Resource Monitor app` ||
| `services.msc`            | Opens `Services` snap in ||
| `shell:appsfolder`        | Opens `Applications` folder | Useful for creating shortcuts to `Microsoft Store` apps |
| `shell:mycomputerfolder`  | Opens `This PC` folder ||
| `shell:recyclebinfolder`  | Opens `Recycle Bin` folder                          ||
| `shell:startup`           | Opens `Startup` folder                              ||
| `shutdown -h`             | Hibernate computer ||
| `shutdown -l`             | Log off                                             ||
| `shutdown -r -fw`         | Restart Windows and boot in to `BIOS` / `UEFI` ||
| `shutdown -r -o`          | Restart Windows and boot in to `Recovery Environment` ||
| `shutdown -r -f -t 00`    | Force Restarts Windows immediately ||
| `shutdown -s -f -t 00`    | Force Shuts down Windows immediately ||
| `snippingtool`            | Opens `Snipping Tool` app ||
| `sysdm.cpl`               | Opens `System Properties` window                    | Quick access to `System Restore` |
| `taskmgr`                 | Opens `Task Manager` app ||
| `taskschd.msc`            | Opens `Task Scheduler` snap in ||
| `timedate.cpl`            | Opens `Date and Time` window ||
| `verifier`                | Opens `Driver Verifier Manager` app ||
| `videos`                  | Opens current user's `Videos` folder ||
| `vlc`                     | Opens `VLC Media Player` app _(if installed)_ ||
| `winver`                  | Opens `About Windows` window                        | Quick way to check installed Windows edition _(Home/Pro/Enterprise)_, version, and build |
| `wt`                      | Opens `Windows Terminal` app                        ||
| `%APPDATA%`               | Opens current user's `AppData\Roaming` folder ||
| `%LOCALAPPDATA%`          | Opens current user's `AppData\Local` folder ||
| `%SYSTEMDRIVE%`           | Opens the root folder of the system drive ||
| `%TEMP%`                  | Opens current user's `Temp` folder ||
| `%USERPROFILE%`           | Opens current user's profile folder ||
| `%WINDIR%`                | Opens `Windows` folder ||
<!-- add sfc, dism, chkdsk, defrag, cleanmgr -->

## Hotkeys

### Windows

<!-- populate hotkeys (i.e Win+R, Win+E, Win+D, Ctrl+Shift+ESC, Win+X > A, Win+X > M, Win+X > U > U, etc..) -->

## Resources

### Hardware

|    |     |
|:-- | :-- |
| [iFixIt - Electronics Skills](https://www.ifixit.com/Device/Electronics_Skills) | Learn general device repair and electronics skills |
| [iFixIt - Repair Guides](https://www.ifixit.com/Guide) | Repository of repair guides for specific devices |
| [Repair Wiki](https://repair.wiki/) | Guides for troubleshooting more specific or niche device issues |
| [Keyboard Checker](https://keyboardchecker.com/) | Keyboard tester |
| [HardwareTester - Midi Tester](https://hardwaretester.com/midi) | Test MIDI input devices |
| [HardwareTester - Gamepad Tester](https://hardwaretester.com/gamepad) | Test Gamepads / Controllers |
| [HardwareTester - Microphone Tester](https://hardwaretester.com/microphone) | Test Microphones |
| [PassMark - CPU Benchmarks](https://www.cpubenchmark.net/) | Compare CPU's |
| [PassMark - Videocard Benchmarks](https://www.videocardbenchmark.net/) | Compare Videocards |
| [PassMark - Memory Benchmarks](https://www.memorybenchmark.net/) | Compare Memory Modules |
| [PassMark - Hard Drive Benchmarks](https://www.harddrivebenchmark.net/) | Compare HDD's / SSD's |

### Networking

|    |     |
|:-- | :-- |
| [Port Forward](https://portforward.com/) | Repository of router port forwarding guides and ports for common software |
| [Router Passwords](https://www.routerpasswords.com/) | Repository of default router usernames/passwords and IP addresses |
| [SpeedTest](https://www.speedtest.net/) | Test internet connection download, upload, ping speeds |
chr
### Security

|    |     |
|:-- | :-- |
| [Bitwarden Password Generator](https://bitwarden.com/password-generator/#password-generator) | Great password generator to create unique Passphrases<hr>_Type = Passphrase, Capitalize = Y, Include Number = Y, Word Separator = -, Length = 3_ |
| [Have I Been Pwned](https://haveibeenpwned.com/) ||

### Software

|    |     |
|:-- | :-- |
| [winstall](https://winstall.app/) | Make winget install scripts to batch install software |
| [Ninite](https://ninite.com/) | Make standalone batch software installers |
| [Adobe PDF Tools](https://www.adobe.com/au/acrobat/online.html) | Free to use PDF tools, use Incognito/Private mode to exceed free 'try' limits |
| [Photopea](https://www.photopea.com/) | Free Photoshop alternative that runs in the web browser |
| [PrintFriendly](https://www.printfriendly.com/) | Convert various file formats to PDF |
| [Watermark Remover](https://www.watermarkremover.io/) | AI watermark removing tool, use Incognito/Private mode to exceed free 'try' limits |

### Phonetic Alphabet

The NATO Phonetic Alphabet can be very useful when trying to provide remote support over the phone

<!-- reference: https://www.worldometers.info/languages/nato-phonetic-alphabet/ -->

|         |           |
| :--:    | :--       |
| A       | Aplha     |
| B       | Bravo     |
| C       | Charlie   |
| D       | Delta     |
| E       | Echo      |
| F       | Foxtrot   |
| G       | Golf      |
| H       | Hotel     |
| I       | India     |
| J       | Juliett   |
| K       | Kilo      |
| L       | Lima      |
| M       | Mike      |
| N       | November  |
| O       | Oscar     |
| P       | Papa      |
| Q       | Quebec    |
| R       | Romeo     |
| S       | Sierra    |
| T       | Tango     |
| U       | Uniform   |
| V       | Victor    |
| W       | Whiskey   |
| X       | X-ray     |
| Y       | Yankee    |
| Z       | Zulu      |
