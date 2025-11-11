# Data Transfer - Backup Script
# --------------------------------------------------
# This script will use a variety of tools to export
# a PC's user data and configurations to the current
# working directory.
# This export / backup can then be used to restore
# on to aother device.

Write-Output "Data Transfer - Backup Script"
Write-Output "----------------------------------------"
write-Output ""

$directory=$args[0]

# echo current working directory
Write-Output "Current Working Directory: $PWD"
Write-Output "called from directory: $directory"







Start-Sleep -Seconds 30