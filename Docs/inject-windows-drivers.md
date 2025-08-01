---
title: 'How to Inject Drivers in to a Windows installer'
author: Buckland, Shaun
keywords: [inject, windows, driver, installer, offline]
abstract: This doc will show how to inject driver(s) in to an offline Windows installer such as a Windows 11 USB installer.
geometry: a4paper,margin=2cm
---

<!--
References:
https://woshub.com/integrate-drivers-to-windows-install-media/
 -->

# How to Inject Drivers in to a Windows installer 

## Prep

- Have a folder with extracted drivers ready to go\
`C:\drivers\` for this example
- Create an empty directory ready to mount the Windows image to for editing\
`C:\mount\` for this example
- Have a Windows image ready to go\
`F:\sources\install.wim` for this example

## Mount

- Open Powershell as admin
- Find index of the Windows image you want to mount\
`Get-WindowsImage -ImagePath F:\sources\install.wim`
- `Mount-WindowsImage -Path C:\mount\ -ImagePath F:\sources\install.wim -Index 1`

## Add Drivers

- `Add-WindowsDriver -Path C:\mount\ -Driver C:\drivers\ -Recurse -ForceUnsigned`


## Unmount

- `Dismount-WindowsImage -Path C:\mount\ –Save`

