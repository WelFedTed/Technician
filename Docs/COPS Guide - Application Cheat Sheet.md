<!-- Render to .PDF using https://md2pdf.netlify.app/ at 75% scaling (Print to PDF) -->

# COPS Guide - Application Cheat Sheet

<table>
    <td><em>contributors: <a href="mailto:shaun@copscorp.com.au" title="Buckland, Shaun (shaun@copscorp.com.au)">shaun@</a></em></td>
    <td><div style='text-align: right;'><em>updated: 02-JUL-2024</em></div></td>
</table>

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
| License Keys (Extract)                 | [Product Key Scanner](https://www.nirsoft.net/utils/product_key_scanner.html)                          | -                                        | <font style="color:red">**✓**</font> | _Extract license keys for Windows and/or Office_                                |
| License Keys (Extract)                 | [ProduKey](https://www.nirsoft.net/utils/product_cd_key_viewer.html)                                   | -                                        | <font style="color:red">**✓**</font> | _May find licenses for some older products that Product Key Scanner could miss_ |
| Software (Uninstall + Remnant Removal) | [RevoUninstaller](https://www.revouninstaller.com/)                                                    | RevoUninstaller.RevoUninstaller          |                  ✕                   |                                                                                 |
| Remote Access                          | [TeamViewer](https://www.teamviewer.com/en-au/)                                                        | winget install TeamViewer.TeamViewer     |                  ✕                   | _May run into connection limit on free version_                                 |
| Remote Access                          | [UltraViewer](https://www.ultraviewer.net/en/)                                                         | winget install DucFabulous.UltraViewer   |                  ✕                   | _Alternative to TeamViewer_                                                     |
| User Profile (Backup/Migrate)          | [Transwiz](https://www.forensit.com/move-computer.html)                                                | -                                        |                  ✕                   |                                                                                 |
