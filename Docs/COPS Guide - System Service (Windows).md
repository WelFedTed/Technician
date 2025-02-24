<!-- Render to .PDF using https://md2pdf.netlify.app/ at 75% scaling (Print to PDF) -->

# COPS Guide - System Service (Windows)

<table>
    <td><em>contributors: <a href="mailto:shaun@copscorp.com.au" title="Buckland, Shaun (shaun@copscorp.com.au)">shaun@</a></em></td>
    <td><div style='text-align: right;'><em>updated: 24-FEb-2025</em></div></td>
</table>

## Software

- Restart Windows
- Configure System Restore</br>_Try to set at least 7% allocation_
- Create a new System Restore point</br>_Name it something like "COPS - Pre System Service"_
- Task Manager
  - Disable unwanted startup items
- [Wintoys](https://apps.microsoft.com/detail/9p8ltpgcbzxd)
  - Install [Wintoys](https://apps.microsoft.com/detail/9p8ltpgcbzxd)
    > _`winget install wintoys` or</br>`winget install 9P8LTPGCBZXD` or</br>`ms-windows-store://pdp/?ProductId=9P8LTPGCBZXD`_
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
    -
- Update software
  - Windows Update
    > _old Windows 10 builds can use the Windows 10 Update Assistant to jump to the latest build_
  - Update Apps via Winget
  - Update Apps via Microsoft Store
  - Update Office Apps
- Update Drivers
  - Update Drivers using `SDIO`
  - Verify Drivers using `verifier`
- Maintenance
  - Run the following commands:
    > sfc /scannow
    > dism /online /cleanup-image /startcomponentcleanup /resetbase
    > dism /online /cleanup-image /restorehealth
    > sfc /scannow
    > chkdsk c: /r /scan /perf
    > defrag c: /o
  - Memory Diagnostics
    - Run `Windows Memory Diagnostics`
    - Click 'Restart now and check for problems (recommended)'
    - After Windows boots back up, check results:</br>
      `Event Viewer` > Windows Logs > System > Filter Current Log... > Event sources > Tick 'MemoryDiagnostics-Results' > Click OK
  - Create a new System Restore point</br>_Name it something like "COPS - Post System Service"_

## Hardware

- Check all buttons and ports are free from debris and working functioning correctly
- Air compress out system as required
- Wipe down device and clean surfaces
- Add a `Serviced by COPS` sticker or replace old worn stickers as required
