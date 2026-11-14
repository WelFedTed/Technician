# Safely ejects a USB drive, like "Safely Remove Hardware" in the taskbar: the drive's USB device is asked to
# stop, and Windows says no (a veto) if anything still has files or folders open on it.
# Eject.cmd in the root of the USB tool copies this to %TEMP% and runs it from there, so that neither the
# launcher nor this script is holding the drive open.
#
# Usage: eject-drive.ps1 -Drive E: [-WhatIf]
#   -WhatIf   only show which device would be ejected
param(
    [Parameter(Mandatory)][string]$Drive,
    [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'
$Drive = $Drive.Trim().TrimEnd('\').ToUpper()
if ($Drive -notmatch '^[A-Z]:$') { $Drive = $Drive.Substring(0, 1) + ':' }
$Host.UI.RawUI.WindowTitle = "Eject $Drive"
# nothing in this window should be using the drive
Set-Location -LiteralPath $env:TEMP

function Say([string]$message) { Write-Host $message }

function Finish([int]$code) {
    Say ''
    if ($code -eq 0) { Say 'This window closes by itself in 10 seconds.' } else { Say 'Press any key to close this window.' }
    $deadline = (Get-Date).AddSeconds(10)
    while ($code -ne 0 -or (Get-Date) -lt $deadline) {
        # (no keyboard when the input is redirected, eg. run from another script: just close)
        try { if ([Console]::KeyAvailable) { break } } catch { break }
        Start-Sleep -Milliseconds 200
    }
    # this copy lives in %TEMP%; tidy it up (only the copy, never the one on the USB)
    if ($PSCommandPath -like "$env:TEMP\*") { Remove-Item -LiteralPath $PSCommandPath -Force -ErrorAction SilentlyContinue }
    exit $code
}

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;

public static class UsbToolEject {
    [DllImport("cfgmgr32.dll", CharSet = CharSet.Unicode)]
    static extern int CM_Locate_DevNodeW(out uint devInst, string deviceId, int flags);
    [DllImport("cfgmgr32.dll")]
    static extern int CM_Get_Parent(out uint parent, uint devInst, int flags);
    [DllImport("cfgmgr32.dll")]
    static extern int CM_Get_DevNode_Status(out uint status, out uint problem, uint devInst, int flags);
    [DllImport("cfgmgr32.dll", CharSet = CharSet.Unicode)]
    static extern int CM_Get_Device_IDW(uint devInst, StringBuilder buffer, int length, int flags);
    [DllImport("cfgmgr32.dll", CharSet = CharSet.Unicode)]
    static extern int CM_Request_Device_EjectW(uint devInst, out int vetoType, StringBuilder vetoName, int length, int flags);

    const uint DN_REMOVABLE = 0x00004000;

    public static uint Locate(string deviceId) {
        uint devInst;
        int cr = CM_Locate_DevNodeW(out devInst, deviceId, 0);
        if (cr != 0) throw new Exception("Couldn't find the device " + deviceId + " (error " + cr + ")");
        return devInst;
    }

    public static string Id(uint devInst) {
        var sb = new StringBuilder(400);
        return CM_Get_Device_IDW(devInst, sb, sb.Capacity, 0) == 0 ? sb.ToString() : "";
    }

    // the disk itself, or the first device above it that Windows can remove (eg. the USB device the disk is on)
    public static uint FindRemovable(uint devInst) {
        uint current = devInst;
        for (int level = 0; level < 8; level++) {
            uint status, problem;
            if (CM_Get_DevNode_Status(out status, out problem, current, 0) == 0 && (status & DN_REMOVABLE) != 0) return current;
            uint parent;
            if (CM_Get_Parent(out parent, current, 0) != 0) break;
            current = parent;
        }
        return 0;
    }

    // 0 when ejected; otherwise the veto type (why Windows said no), with the name of what's in the way
    public static int Eject(uint devInst, out string vetoName) {
        int vetoType;
        var sb = new StringBuilder(400);
        int cr = CM_Request_Device_EjectW(devInst, out vetoType, sb, sb.Capacity, 0);
        vetoName = sb.ToString();
        if (cr != 0 && vetoType == 0) { vetoName = "error " + cr; return -1; }
        return vetoType;
    }
}
'@

$vetoReasons = @{
    1 = 'a legacy device is in the way'
    2 = 'Windows is still closing files on it'
    3 = 'a program is using it'
    4 = 'a Windows service is using it'
    5 = 'files or folders on it are still open'
    6 = 'another device on it is in use'
    7 = 'a driver is using it'
    8 = 'the request was refused'
    9 = 'not enough power'
    10 = "it can't be turned off"
    11 = 'a legacy driver is using it'
    12 = 'this account isn''t allowed to eject it'
}

Say "Ejecting $Drive"
Say ('-' * 60)

# ---- is this a USB drive (and not the PC's own disk)?
if ($Drive -eq $env:SystemDrive.ToUpper()) { Say "$Drive is the drive Windows runs from, so it won't be ejected."; Finish 1 }
$logical = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$Drive'"
if (-not $logical) { Say "There's no drive $Drive on this PC (it may already have been ejected)."; Finish 1 }
if ($logical.DriveType -eq 4) { Say "$Drive is a network drive, not a USB drive."; Finish 1 }
$disk = $logical | Get-CimAssociatedInstance -ResultClassName Win32_DiskPartition | Get-CimAssociatedInstance -ResultClassName Win32_DiskDrive | Select-Object -First 1
if (-not $disk) { Say "Couldn't find the disk $Drive is on (it may be a mapped folder or a virtual drive), so it won't be ejected."; Finish 1 }
$storage = Get-CimInstance -Namespace root/Microsoft/Windows/Storage -ClassName MSFT_Disk -Filter "Number=$($disk.Index)" -ErrorAction SilentlyContinue
# bus types: 7 = USB, 12 = SD, 13 = MMC
$isUsb = ($storage -and $storage.BusType -in @(7, 12, 13)) -or $disk.InterfaceType -eq 'USB' -or $logical.DriveType -eq 2
if (-not $isUsb) { Say "$Drive is on $($disk.Model), which isn't a USB drive, so it won't be ejected."; Finish 1 }
$others = @(Get-CimInstance Win32_LogicalDisk | Where-Object {
    $_.DeviceID -ne $Drive -and ($_ | Get-CimAssociatedInstance -ResultClassName Win32_DiskPartition | Get-CimAssociatedInstance -ResultClassName Win32_DiskDrive | Where-Object Index -eq $disk.Index)
} | ForEach-Object DeviceID)
Say "Drive:  $Drive $($logical.VolumeName) on $($disk.Model)"
if ($others.Count) { Say "Also on this disk (ejected with it): $($others -join ', ')" }

# ---- the device to eject
$diskNode = [UsbToolEject]::Locate($disk.PNPDeviceID)
$target = [UsbToolEject]::FindRemovable($diskNode)
if ($target -eq 0) { Say "Windows doesn't list $Drive as removable, so it can't be ejected this way."; Finish 1 }
Say "Device: $([UsbToolEject]::Id($target))"
if ($WhatIf) { Say ''; Say "(-WhatIf: not ejected)"; Finish 0 }

# ---- eject; the launcher window may take a moment to let go of the drive, so try a few times
Start-Sleep -Seconds 1
$veto = 0
$vetoName = ''
for ($try = 1; $try -le 5; $try++) {
    $veto = [UsbToolEject]::Eject($target, [ref]$vetoName)
    if ($veto -eq 0) { break }
    Start-Sleep -Seconds 2
}
Say ''
if ($veto -eq 0) {
    Say "Done: $Drive can now be safely removed."
    Finish 0
}
$reason = if ($vetoReasons.ContainsKey($veto)) { $vetoReasons[$veto] } else { "Windows said no (veto $veto)" }
Say "Couldn't eject ${Drive}: $reason."
if ($veto -eq 3 -and $vetoName) { Say "The program: $vetoName" }
elseif ($vetoName) { Say "Details: $vetoName" }
Say 'Close any files, folders, programs or command prompts open on the drive, then run Eject.cmd again.'
Finish 1
