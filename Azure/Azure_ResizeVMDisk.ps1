<#
.SYNOPSIS
    Script is not realy needed anymore Azure now supports live resize of data disks. It is still usable for resizing OS disks.
    https://learn.microsoft.com/en-us/azure/virtual-machines/windows/expand-os-disk#expand-without-downtime
    Resize a disk attached to a VM and resize the partition on the disk in 

.DESCRIPTION
    This script will resize a disk attached to a VM. The VM will be stopped and started to resize the disk.
    It wil also resize the partition on the disk. The disk must be attached to the VM as a data disk.

    This script can be used in a Azure Automation Runbook to plan the resize of a Disk. Give the automation identity the right permissions to the VM/Disk
.Parameter NewSize
    The new size of the disk in GB
.PARAMETER VMName
    The name of the VM as shown in the Azure portal
.PARAMETER diskName
    The name of the disk as shown in the Azure portal
.PARAMETER rgName
    The name of the resource group
.PARAMETER DriveLetter
    The drive letter of the disk within Windows
.NOTES
	Author: Rik Merkens
    GitHub: https://github.com/RikMerkens/Scripts
	Last Updated: 11-04-2024
    Version 1.1
#>

Param
(
    [Parameter (Mandatory = $true)]
    [String] $VMName,

    [Parameter (Mandatory = $true)]
    [String] $diskName,

    [Parameter (Mandatory = $true)]
    [String] $rgName,

    [Parameter (Mandatory = $true)]
    [String] $DriveLetter,

    [Parameter (Mandatory = $true)]
    [Int] $NewSize

)

try {
    "Logging in to Azure..."
    Connect-AzAccount -Identity
}
catch {
    Write-Error -Message $_.Exception
    throw $_.Exception
}

$VM = Get-AzVM -Name $VMName -status

if ($VM.PowerState -like "VM running") {
    "Deallocating VM"
    Stop-AzVM -Name $VM.Name -ResourceGroupName $rgName -Force
    "VM Deallocated"
    $DidVMRun = $true 
}

$disk = Get-AzDisk -ResourceGroupName $rgName -DiskName $diskName
$disk.DiskSizeGB = $NewSize
"Updating Disk Size"
Update-AzDisk -ResourceGroupName $rgName -Disk $disk -DiskName $disk.Name

if ($DidVMRun) {
    "Starting VM"
    Start-AzVM -Name $VM.Name -ResourceGroupName $rgName
    "VM Started"
    Start-Sleep -Seconds 60
    $remoteCommand =
    @"
Resize-Partition -DriveLetter $DriveLetter -Size ((Get-PartitionSupportedSize -DriveLetter $driveLetter).sizeMax) -confirm:`$false
"@
    # Save the command to a local file
    Set-Content -Path .\DriveCommand.ps1 -Value $remoteCommand
    "Sending AzVMRunCommand to Windows/VM to resize partition"
    Invoke-AzVMRunCommand -ResourceGroupName $rgName -Name $VM.Name -CommandId 'RunPowerShellScript' -ScriptPath .\DriveCommand.ps1
}


# https://faultbucket.ca/2019/05/run-script-inside-azure-vm-from-powershell/

