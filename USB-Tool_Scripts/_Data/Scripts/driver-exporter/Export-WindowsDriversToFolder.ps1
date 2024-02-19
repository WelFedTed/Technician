$date = Get-Date -Format yyyy-MM-dd
$dir = "C:\Drivers\_Backup_$date\"

echo "Powershell-3rd-Party-Driver-Exporter"
echo "------------------------------------------------------------"

echo "Exporting all installed 3rd-Party Drivers to: $dir"
echo ""
echo "Making backup directory..."
New-Item -ItemType Directory -Force -Path "$dir"
echo ""
echo "Exporting drivers..."
DISM /Online /Export-Driver /Destination:"$dir"