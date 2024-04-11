<#
.SYNOPSIS
    Adjust size of Azure VM

.DESCRIPTION
   This script will adjust the size of a Microsoft Azure virtual machine based on input.
    Warning!! When running this script the VM will be stopped and restarted. 
    Deallocating the VM releases any dynamic IP addresses assigned to the VM. The OS and data disks are not affected.

    This script can be used in a Azure Automation Runbook to plan the resize of a VM. Give the automation identity the right permissions to the VM
.Parameter NewSize
    The new VM SKU such as Standard_B8ms

.NOTES
	Author: Rik Merkens
    GitHub: https://github.com/RikMerkens/Scripts
	Last Updated: 10-12-2021
    Version 1.0
#>


Param
(
    [Parameter (Mandatory= $true)]
    [String] $VMName,

    [Parameter (Mandatory= $true)]
    [String] $rgName,

    [Parameter (Mandatory= $true)]
    [String] $NewSize
)

try
{
    "Logging in to Azure..."
    Connect-AzAccount -Identity
}
catch {
    Write-Error -Message $_.Exception
    throw $_.Exception
}

$VM = Get-AzVM -Name $VMName -status

if ($VM.PowerState -like "VM running"){
    "Deallocating VM"
    Stop-AzVM -Name $VM.Name -ResourceGroupName $rgName -Force
    "VM Deallocated"
    $DidVMRun = $true 
}

$vm.HardwareProfile.VmSize = $NewSize
Update-AzVM -VM $vm -ResourceGroupName $rgName
"Size Updated"

if ($DidVMRun){
    "Starting VM"
    Start-AzVM -Name $VM.Name -ResourceGroupName $rgName
    "VM Started"
}