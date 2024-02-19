$directory=$args[0]

echo "Powershell-Directory-Driver-Installer"
echo "------------------------------------------------------------"

echo "Scanning directory for drivers..."
$driverTotal=Get-ChildItem $directory -Recurse -Filter "*.inf" | Measure-Object | %{$_.Count}
echo "$driverTotal drivers found."

$driverCount=0
Get-ChildItem $directory -Recurse -Filter "*.inf" |
ForEach-Object {
    $driverCount++
    echo ""
    echo ""
    echo "Installing driver $driverCount of $driverTotal..."
    echo "------------------------------------------------------------"
    PNPUtil.exe /add-driver $_.FullName /install
}