<!-- Render to .PDF using https://md2pdf.netlify.app/ at 75% scaling (Print to PDF) -->

# COPS Guide - Data Transfer (Windows)

<table>
    <td><em>contributors: <a href="mailto:shaun@copscorp.com.au" title="Buckland, Shaun (shaun@copscorp.com.au)">shaun@</a></em></td>
    <td><div style='text-align: right;'><em>updated: 04-JUL-2024</em></div></td>
</table>

## Backup

- Restart Windows
  > _Force Restart Windows (`shutdown -r -f -t 00`) now to provide a clean slate for proceeding_
- Disable Antivirus
  > _Some of our extraction tools prompt false positives in most security packages_
- Create a Job# number folder on a Transfer Drive
  > _Create a new folder with the current job number (ie. 'Job#5000') to save User Data to_
- User Profile
  > _use Forensit Transwiz, Fast Pack (no compression), use default filename_
- Web Browsers
  > _For each web browser installed export the following:_
  - Export Bookmarks _(ie. 'Web Browser - Google Chrome - Bookmarks - 2024-07-15.html')_
    > _Google Chrome URL: `chrome://password-manager/passwords` or `chrome://settings/passwords` (older versions) </br> Microsoft Edge URL: `edge://favorites` </br> Mozilla Firefox Hotkey: `Ctrl+Shift+O`_
  - Export Passwords _(ie. 'Web Browser - Google Chrome - Passwords - 2024-07-15.csv')_
    > _Google Chrome URL: `chrome://password-manager/passwords` or `chrome://settings/passwords` (older versions) </br> Microsoft Edge URL: `edge://wallet/passwords` or `edge://settings/password`s (older versions) </br> Mozilla Firefox URL: `about:logins`_
- Installed Programs _(ie. 'Installed Programs - 2024-07-15.html')_
  > _use Nirsoft UninstallView, save all as Horizontal HTML_
- License Keys _(ie. 'License Keys - 2024-07-15.htmal')_
  > _use Nirsoft ProduKey and Nirsoft Product Key Scanner_
- Check C: Drive for unusual files/folders
  > _copy to Job folder copying the C: Drive file structure (TransferDrive:\Job#5000\C\FolderToSave)_
- [<font style="color:ORANGE">OPTIONAL</font>] Create Winget Install Script
  > _https://winstall.app/ - Select Desired Programs - Generate Script - Download both Batch (.bat) and PowerShell (.ps1) scripts_
- Drivers _('TransferDrive:\Job#5000\Drivers - 2024-07-24\')_
  > _Open PowerShell as Administrator and run (update with your export folder location): </br> `Export-WindowsDriver -Online -Destination REPLACE-WITH-EXPORT-FOLDER`_
- Enable Antivirus
- Create a System Restore point

## Restore
