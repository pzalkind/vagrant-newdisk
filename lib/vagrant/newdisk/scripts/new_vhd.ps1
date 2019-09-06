#Requires -Modules VagrantMessages

param(
    [parameter (Mandatory=$true)]
    [string] $DiskPath,
    [parameter (Mandatory=$true)]
    [uint64] $DiskSize,
	[parameter (Mandatory=$false)]
	[switch] $Fixed=$false
)

try {
	if ($Fixed) {
		New-VHD -Path $DiskPath -Fixed -SizeBytes $DiskSize
	} else {
		New-VHD -Path $DiskPath -Dynamic -SizeBytes $DiskSize
	}
} catch {
    $ErrorMessage = $_.Exception.Message
    Write-ErrorMessage "Failed to create VHD on $DiskPath : $ErrorMessage"
    exit 1    
}