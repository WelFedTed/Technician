<!-- Render to .PDF using https://md2pdf.netlify.app/ at 75% scaling (Print to PDF) -->

# COPS Guide - Virus/Malware Removal (Windows)
---
<table>
    <td><em>contributors: <a href="mailto:shaun@copscorp.com.au" title="Buckland, Shaun (shaun@copscorp.com.au)">shaun@</a></em></td>
    <td><div style='text-align: right;'><em>updated: 02-JUL-2024</em></div></td>
</table>


## PRE
- [<font style="color:RED">**IMPORTANT**</font>] [Air Gap Device](## "AAA")
> _Ensure device is disconnected from all networks before RKill is run successfully and RATs ( Remote Access Tools ) removed, to ensure malicious actors do not re-connect to the device while it's still compromised_
- Enable System Restore (set to 7% allocation if enough free disk space)
- [<font style="color:ORANGE">OPTIONAL</font>] Create a new [System Restore](https://support.microsoft.com/en-gb/windows/create-a-system-restore-point-77e02e2a-3298-c869-9974-ef5658ea3be9) point "**COPS - Pre Virus/Malware Removal**"
> _This System Restore point will be wiped out in a later step (post-virus/malware removal), as malware can persist in old System Restore points_
- Restart Windows
>_Force Restart Windows (`shutdown -r -f -t 00`) now to provide a clean slate for proceeding_
- Create [COPS Folder](## "'%SYSTEMDRIVE%\COPS' ( likely 'C:\COPS' )")
- Add [COPS Folder](## "'%SYSTEMDRIVE%\COPS' ( likely 'C:\COPS' )") to installed [antivirus exclusions list(s)](https://support.microsoft.com/en-au/windows/add-an-exclusion-to-windows-security-811816c0-4dfd-af4a-47e4-c301afe13b26 "How to add an exclusion to Windows Security")
- Copy Rkill folder from USB Tool to "%SYSTEMDRIVE%\COPS" (RKill can't run from a write-blocked drive)
- Run an Rkill executable as Administrator
- Move Rkill.txt from "%USERPROFILE%\Desktop" to "%SYSTEMDRIVE%\COPS"
- Revo Uninstaller
    - xxx
- Disk Cleanup
    - Run `Win+R`: `cleanmgr /sageset:10`
    >_This will open the Disk Cleanup utility to create settings for Profile 10_
    - Click `Clean up system files`
    - Select all checkboxes except for the two **System error** options
    >_`System error memory dump files` + `System error minidump files`_
    >_</br>(you can click on an option, and then use the UP + DOWN arrows + Space Bar to quickly check or uncheck options)_
    - Click `OK`
    - Run `Win+R`: `cleanmgr /sagerun:10`
    >_This will run the Disk Cleanup utility to using Profile 10's settings`_

## MAIN
- Connect to Internet
- [<font style="color:ORANGE">OPTIONAL</font>] [AdwCleaner](https://www.malwarebytes.com/adwcleaner)
> _AdwCleaner crashes out of UVK's automation, so run it now instead if you want to use it_
- [<font style="color:ORANGE">OPTIONAL</font>] [Spybot - Search & Destroy](https://www.safer-networking.org/free-download/)
> _Spybot is a thorough malware removal tool, but it can take a very long time to complete it's scans_
- [<font style="color:ORANGE">OPTIONAL</font>] [Windows Defender Offline Scan](https://support.microsoft.com/en-au/windows/help-protect-my-pc-with-microsoft-defender-offline-9306d528-64bf-4668-5b80-ff533f183d6c "How to use Windows Defender Offline")
- [<font style="color:ORANGE">OPTIONAL</font>] Create a new System Restore point "**COPS - Pre Virus/Malware Removal**"
- Ultra Virus Killer
    - xxx
## POST
- [<font style="color:ORANGE">OPTIONAL</font>] Create a new System Restore point "**COPS - Pre Windows Update**"
- Update Windows (no preview updates)
- Update Apps via Microsoft Store
- Update Apps via Windows Package Manager (winget)
    - winget source update
    - winget upgrade --all --silent
- [<font style="color:ORANGE">OPTIONAL</font>] Create a new System Restore point "**COPS - Pre Driver Update**"
- Update Drivers (SDIO)
- Verify Drivers (verifier)
    - **Turn On Windows Verifier:**
        - Run `Win+R`: `verifier`
        - Select `Create standard settings`
        - Click `Next`
        - Select `Automatically select all drivers on this computer`
        - Click `Finish`
        - Restart Windows (`shutdown -r -f -t 00`)
        >_Windows Verifier works by stressing out drivers as they're loaded (it is expected that the computer's performance will be impacted while verifier is enabled)
        ></br>If Windows loads into the desktop OK and does not crash with verifier enabled, then all is good and you can proceed to turn it off_
    - **Turn Off Windows Verifier:**
        - Run `Win+R`: `verifier`
        - Select `Delete existing settings`
        - Click `Finish`
        - Restart Windows (`shutdown -r -f -t 00`)
- System Maintenance/Repair
    - sfc /scannow
    - dism /online /cleanup-image /startcomponenetcleanup /resetbase
    - dism /online /cleanup-image /restorehealth
    - sfc /scannow
    - chkdsk /r /scan /perf
- Create a new System Restore point "**COPS - Post Virus/Malware Removal**"


<!-- 
    TO DO:
    - fill out large tasks sub-tasks (revo, cleanmgr, uvk, verifier, etc..)
    - document more comprehensively with tooltips and/or images
    - mouse over tool tips
        [Display text](## "Hover text")
    - implement coloured text and improved document formatting
    - make markdown doc work with a technician wiki? (Obsidian knowledgebase?)
-->


