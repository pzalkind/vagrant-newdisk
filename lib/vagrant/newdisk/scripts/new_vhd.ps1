#Requires -Modules VagrantMessages

param(
    [parameter (Mandatory=$true)]
    [string] $DiskPath,
    [parameter (Mandatory=$true)]
    [uint64] $DiskSize
)

try {
    New-VHD -Path $DiskPath -Dynamic -SizeBytes $DiskSize
} catch {
    $ErrorMessage = $_.Exception.Message
    Write-ErrorMessage "Failed to create VHD on $DiskPath : $ErrorMessage"
    exit 1    
}