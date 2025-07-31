---
title: 'How to Inject Drivers in to a Windows installer'
author: Buckland, Shaun
keywords: [inject, windows, driver, installer, offline]
abstract: This doc will show how to inject driver(s) in to an offline Windows installer such as a Windows 11 USB installer.
---

# How to Inject Drivers in to a Windows installer 

## Prep

- Have a folder with extracted drivers ready to go\
`C:\drivers\` for this example
- Have a Windows image ready to go\
`F:\sources\install.wim` for this example

## Mount

- Open Powershell as admin
- Find index of the Windows image you want to mount\
`Get-WindowsImage -ImagePath`
- aa