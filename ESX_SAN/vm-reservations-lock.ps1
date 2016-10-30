$vmlist = Get-VM -name "XD*"

Foreach ($guest in $vmlist){ 
    $guest_config = New-Object VMware.Vim.VirtualMachineConfigSpec
    $guest_config.memoryReservationLockedToMax = $true
    $guest.ExtensionData.ReconfigVM_task($guest_config)
    Write-Verbose "Updated Reservation: $guest" -Verbose
    }