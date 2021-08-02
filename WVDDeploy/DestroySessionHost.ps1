Param(
    [Parameter(Mandatory = $true)]
    [String]$vmResourceGroup,
    [Parameter(Mandatory = $true)]
    [String]$resourceGroup,
    [Parameter(Mandatory = $true)]
    [String]$hostPoolName,
    [Parameter(Mandatory = $true)]
    [String]$domain
)

$VMs = Get-AzVM -ResourceGroupName $vmResourceGroup  -Status
$VMList = @()

foreach ($VM in $VMs) {
    if (($VM.tags["Remove"]) -eq "true") { 
        Write-Host "$VM.name added to Decommission script."
        $VMList += $VM
    }
}

Write-Host "Removing old AVD Session Hosts and all dependencies"

$ASID = $VMList[0].AvailabilitySetReference.id

$failedResources = @()

foreach ($VM in $VMList) {
    
    Write-Host "Removing $($VM.Name) from Host Pool"
    try {
        Remove-AzWVDSessionHost -ResourceGroupName $resourceGroup -HostPoolName $hostPoolName -SessionHostName "$($vm.name).$($domain)" -Force -ErrorAction Stop
        Write-Host "Successfully removed Session Host $($VM.Name) from Host Pool: $($hostPoolName)"
    } catch {
        Write-Host "ERROR: Failed to remove Session Host: $($VM.Name) from Host Pool: $($hostPoolName)"
        Write-Host $_.Exception.Message
    }

    Write-Host "Checking if Session Host is Deallocated"
    if ($VM.PowerState -ne "VM deallocated") {
        Write-Host "Session Host powered on. Deallocating"
        try {
            Stop-AzVM -Name $VM.Name -ResourceGroupName $VM.ResourceGroupName -Force -ErrorAction Stop
            Write-Host "VM $($VM.Name) stopped and deallocated"
        } catch {
            Write-Host "ERROR: Failed to stop VM: $($VM.Name)"
            Write-Host $_.Exception.Message
        }
    }

    Write-Host "Removing Azure VM"
    try {
        $VM | Remove-AzVM -Force -ErrorAction Stop
        Write-Host "VM: $($VM.Name) successfully removed"

        #Remove NIC
        Write-Host "Removing VNICS"
        foreach ($NICID in $VM.NetworkProfile.NetworkInterfaces.Id) {
            $nic = Get-AzNetworkInterface -ResourceGroupName $VM.ResourceGroupName -Name $NICID.Split('/')[-1]
            try {
                Remove-AzNetworkInterface -Name $nic.Name -ResourceGroupName $vm.ResourceGroupName -Force -ErrorAction Stop
                Write-Host "Successfully removed VNIC: $($nic.Name) from VM: $($VM.Name)"
            } catch {
                Write-Host "ERROR: Failed to remove VNIC from VM: $($VM.Name)"
                Write-Host $_.Exception.Message
                $failedResources += $NICID
            }
        }

        #Remove OS Disk
        $osDiskName = $VM.StorageProfile.OSDisk.Name
        $OSDiskID = (Get-Azdisk -Name $osDiskName).id
        try {
            get-azresource -Id $osdiskid | Remove-AzResource -Force -ErrorAction Stop
            Write-Host "Successfully removed OS Disk from VM: $($VM.Name)"
        } catch {
            Write-Host "ERROR: Failed to remove OS Disk from VM: $($VM.Name)"
            Write-Host $_.Exception.Message
            $failedResources += $osDiskID
        }

        Write-Host "Checking if any data disks to remove"
        #Remove Data Disk
        if ($VM.StorageProfile.DataDisks.Count -gt 0) {
            Write-Host "$($VM.StorageProfile.DataDisks.Count) data disks found. Removing . . ."
            foreach ($datadisks in $VM.StorageProfile.DataDisks) {
                $datadiskname = $datadisks.name
                $DataDiskID = (Get-Azdisk -Name $datadiskname).id
                try {
                    Get-AzResource -Id $DataDiskID | Remove-AzResource -Force -ErrorAction Stop
                    Write-Host "Successfully removed Data Disk: $($datadisks.Name) from VM: $($VM.Name)"
                } catch {
                    Write-Host "ERROR: Failed to remove Data Disk $($datadisks.Name) from VM: $($VM.Name)"
                    Write-Host $_.Exception.Message
                    $failedResources += $DataDiskID
                }
            }
        }
        else {
            Write-Host "No data disks to remove from VM: $($VM.Name)"
        }

        Write-Host "Removing Availabilty Set for old Session Hosts"
        #Remove Availability Set
        $AS = Get-AzAvailabilitySet -name $($asid.split("/")[-1])
        try {
            Remove-AzAvailabilitySet -Name $AS.Name -ResourceGroupName $AS.ResourceGroupName -Force -ErrorAction Stop
            Write-Host "Successfully removed Availability Set: $($AS.Name) from VM: $($VM.Name)"
        } catch {
            Write-Host "ERROR: Failed to remove Availability Set: $($AS.Name) from VM: $($VM.Name)"
            Write-Host $_.Exception.Message
            $failedResources += $ASID
        }


    } catch {
        Write-Host "ERROR: Failed to remove VM"
        Write-Host $_.Error.Exception
        $failedResources += $VM.Id
    }
}


    