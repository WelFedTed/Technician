# Data Transfer (Windows)

## Backup

- **Restart Windows**\
  > _Force Restart Windows now to provide a clean environment for proceeding_\
  > `shutdown -r -f -t 00`
- [<font style="color:ORANGE">OPTIONAL</font>] Create a new System Restore point
- **Disable Antivirus**\
  > _Some of our extraction tools prompt false positives in the majority of security software_
- **Create a Job folder on a Transfer Drive**\
  _naming convention:_\
  `Job#5000`
  > _Create a new folder with the current job number to save User Data to_
- **Backup User Profiles**\
  > _Copy `C:\Users\` folder to the Job folder on the Transfer Drive_
- **Backup Web Browsers**\
  _For each web browser installed complete the following:_
  - **Export Bookmarks**\
    _naming convention:_\
    `Web Browser - Google Chrome - Bookmarks - 2024-07-15.html`\
    or\
    `web-browser_google-chrome_bookmarks_2024-07-15.html`
    > _Google Chrome URL:_ `chrome://bookmarks`\
    > _Microsoft Edge URL:_ `edge://favorites`\
    > _AVG Secure Browser URL:_ `secure://bookmarks`\
    > _Mozilla Firefox Hotkey:_ `Ctrl+Shift+O`\
    > _Microsoft Internet Explorer:_ `%USERPROFILE%\Favorites`
  - **Export Passwords**\
    _naming convention:_\
    `Web Browser - Google Chrome - Passwords - 2024-07-15.csv`\
    or\
    `web-browser_google-chrome_passwords-2024-07-15.csv`
    > _Google Chrome URL:_ `chrome://password-manager` or `chrome://settings/passwords` (older Chrome versions)\
    > _Microsoft Edge URL:_ `edge://wallet/passwords` or `edge://settings/passwords` (older Edge versions)\
    > _AVG Secure Browser URL:_ `secure://password-manager` or `secure://settings/passwords` (older Secure Browser versions)\
    > _Mozilla Firefox URL:_ `about:logins`\
    > _Microsoft Internet Explorer:_ use [Nirsoft IE PassView](https://www.nirsoft.net/utils/internet_explorer_password.html)
  - **Sync Accounts**\
    _Try to sync each browser with their relevant accounts if available_\
    _Manual exports of Bookmarks + Passwords is good, but syncing the entire browser is better_
    - _Google Chrome:_ `Google Account`
      > `chrome://sync-internals`\
      > Check Enabled: `Sync Feature Enabled`	= true\
      > Check Account: `Username`\
      > Checked Synced: `Last Synced` = Just now\
      > Check Not Actively Syncing: `Sync Cycle Ongoing` = false\
      > Force Sync (if required): `chrome://extensions` > enable `Developer mode` > click `Update`\
    - _Microsoft Edge:_ `Microsoft Account`
      > _TODO (but it's similar to Chrome)_\
    - _AVG Secure Browser:_ `AVG Account`
      > _TODO (but it's similar to Chrome)_\
    - Mozilla Firefox:_ `Mozilla Account`
      > _TODO_
- **Export Installed Programs List**\
  _naming convention:_\
  `Installed Programs - Nirsoft Uninstallview - 2024-07-15.html`\
  or\
  `installed-programs_nirsoft-uninstallview_2024-07-15.html`
  > _use Nirsoft UninstallView, save all as Horizontal HTML_
- **Export Winget**\
  _naming convention:_\
  `Winget - Export - 2024-07-15.json`\
  or\
  `winget_export_2024-07-15.json`
  > Open `Powershell` or `Command Prompt` as an Administrator\
  > Check Winget is installed `winget -v` (this will throw an error if winget is unavailable)\
  > Update Winget `winget source update`
  > Export Winget's list of installed programs `winget export -o "REPLACE-WITH-TARGET-FILE"`\
  _(update REPLACE-WITH-TARGET-FILE with the target winget export file on the transfer drive)_\
  > Optionally export a list of all programs that Winget does cannot re-install at the same time with this extended command `winget export -o "REPLACE-WITH-TARGET-FILE" >> "winget_unnavailable.txt"`
- **Export License Keys**\
  _naming convention:_\
  `License Keys - Nirsoft Product Key Scanner - 2024-07-15.html`\
  or\
  `license-keys_nirsoft-product-key-scanner_2024-07-15.html`
  > _use Nirsoft Product Key Scanner or Nirsoft ProduKey, save all as Horizontal HTML_
- **Export Emails**
  - Extract Passwords and Server Settings
    - Nirsoft Mail PassView
    - Nirsoft WinMailPassRec
    - Nirsoft PstPassword
  - Backup any accounts set up as POP
    > [_How to export emails to file in Outlook_](https://support.microsoft.com/en-au/office/back-up-your-email-e5845b0b-1aeb-424f-924c-aa1c33b18833)
- **Check C: Drive for unusual files/folders**
  > _copy to Job folder copying the C: Drive file structure (TransferDrive:\\Job\#5000\\C\\FolderToSave)_
- [<font style="color:ORANGE">OPTIONAL</font>] Create Winget Install Script
  > _https://winstall.app/ - Select Desired Programs - Generate Script - Download both Batch (.bat) and PowerShell (.ps1) scripts_
- **Export Drivers**\
  `TRANSFERDRIVE:\\Job#5000\Drivers - 2024-07-15\`\
  or\
  `TRANSFERDRIVER:\\Job#5000\drivers_2024-07-15\`
  > _Open `PowerShell` as an Administrator and run the following script:_\
  `Export-WindowsDriver -Online -Destination "REPLACE-WITH-TARGET-FOLDER"`\
  _(update REPLACE-WITH-TARGET-FOLDER with the target drivers folder on the transfer drive)_
- **Enable Antivirus**

## Prepare New Device _(if required)_

- **Create a Local Account during Windows 10/11 Out of Box Experience (OOBE)**
  - **Option 1: No Internet Connected**\
    Bypass Network Registration
    > _Open Command Prompt:_ `Shift+F10` _(may require pressing `Fn` on some devices)_\
    > _Run command:_ `OOBE\BYPASSNRO` _(this will restart the OOBE if successful)_\
    > _Proceed through OOBE like normal until you get to the Network Selection screen_\
    > _Select_ `I don't have an internet connection` _(if this button is not available the bypass didn't work, proceed to Option 2)_\
    > _Select_ `Continue with limited setup`\
    > _Create a Local Account:_ `COPS` (no password)\
    > _Complete the OOBE as normal_
  - **Option 2: Internet Connected**\
    Force Local Account Creation
    > _Proceed though OOBE like normal until you get to the Login with a Microsoft Account screen_\
    > _Open Command Prompt:_ `Shift+F10` _(may require pressing `Fn` on some devices)_\
    > _Run command:_ `start ms-cxh:localonly`
    > _Create a Local Account:_ `COPS` (no password)\
    > _Complete the OOBE as normal_
  - Note regarding Windows 10/11 S Mode\
    In some cases you won't be able to open the Command Prompt, you may only see it's black box flash up on the screen and quickly dissapear. This is could be a indication of the Windows 10/11 install being in S Mode (Store Mode), which disables access to terminals (i.e. Command Prompt) and execution of non Microsoft Store apps.\
    If you encounter this, you will <u>not</u> be able create a Local Account during the OOBE, and you will need to complete the OOBE with the customer's Microsoft Account.
    After the OOBE is complete and you've reached the Windows Desktop environment, you may need to [Switch Out of S Mode](https://support.microsoft.com/en-au/windows/switching-out-of-s-mode-in-windows-4f56d9be-99ec-6983-119f-031bfb28a307) to proceed with the Data Transfer, as S Mode restricts us from running our tools if required.
    - [<font style="color:ORANGE">OPTIONAL</font>] Switch Out of S Mode\
    <font style="color:RED">[WARNING] SWITCHING OUT OF S MODE IS A PERMANANT CHANGE AND <u>CANNOT</u> BE REVERTED</font>
    > _Connect to the internet_\
    > _Run_ `ms-windows-store://pdp/?productid=BF712690PMLF&OCID=windowssmodesupportpage`\
    > _Follow the prompts to Switch Out of S Mode\
    (this will change the Windows edition installed to Windows 10/11 Home or Pro as per it's installed license)_
- **Configure System Restore**\
- **Check installed Windows' Edition**\
  > _Run_ `winver`
- **Create a new System Restore point**\
  `COPS - Fresh Windows 10/11 Home/Pro Install` (use 10 or 11 and Home or Pro as per `winver`)
- **Connect to the Internet** (if not already)
- **Check Windows is activated**\
  TODO: `ms-settings:activation` or `ms-settings:activation?activationSource=SMC-Article-12440`
- **Configure Time/Date**
- **Configure Windows Update**
  > _Enable_ `TODO: Update other Microsoft products`\
  > _Disable_ `TODO: get me up to date`\
  > _Enable_ `TODO: Notify me when updates are ready`\
  > _Enable_ `TODO: Optimize, download from LAN`
- **Update Apps**\
  via `Microsoft Store`\
  via `Winget`
- **Update Windows**
- **Update Office apps**
> Run `"C:\Program Files\Common Files\microsoft shared\ClickToRun\OfficeC2RClient.exe" /update user forceappshutdown=true`
- **Check Drivers**\
  Bangs(!) exclamation marks in Device Manager indicates missing, incorrect, or corrupt drivers
  > Open `Device Manager` to check for Bangs(!)\
  > Run `Snappy Driver Installer Origin (SDIO)` as an Administrator\
  > Select `TODO: Create a new system restore point`\
  > Select all missing/incorrect/corrupt drivers (as per bangs! in Device Manager)
  > Click `Install`
- **[<font style="color:ORANGE">OPTIONAL</font>] Update Outdated Drivers**
- **Verify Drivers**
  - **Turn On Windows Verifier:**
    - Run `verifier`
    - Select `Create standard settings`
    - Click `Next`
    - Select `Automatically select all drivers on this computer`
    - Click `Finish`
    - Restart Windows `shutdown -r -f -t 00`
      > _Windows Verifier works by stressing out drivers as they're loaded (it is expected that the computer's performance will be impacted while verifier is enabled)_\
      > _If Windows loads into the desktop OK and does not crash with Verifier enabled, then all is good and you can proceed to turn it off_\
      > _If Verifier induces a crash, Windows should produce a Blue Screen of Death (BSOD) with a STOP Code error and information on the driver that crashed, you can use this information to identify the faulty driver that caused the crash and replace it_
  - **Turn Off Windows Verifier:**
    - Run `verifier`
    - Select `Delete existing settings`
    - Click `Finish`
    - Restart Windows `shutdown -r -f -t 00`

## Restore

- **Install Programs**
  > you can use the winget install script for this if you made one \ > _install programs before restoring the user profile, as otherwise some required registry entries may not exist yet_
- **Restore User Profiles**
  > make Administrator, make default user, set no password and set password does NOT expire
- **Copy over any C: Drive files/folders that were backed up**
- **Restart Windows** (this should log in to the restored user profile)
  > open a command prompt window (or similar) as Administrator to ensure account has admin priviledges
- **Install Printer Drivers**
  > If you can not install the printer drivers + software without the printer present, save the printer package installer to `C:\COPS\` and create a shortcut to it on the customer's desktop
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
