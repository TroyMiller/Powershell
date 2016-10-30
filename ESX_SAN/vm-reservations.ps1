$vmlist = Get-VM -name "XD*"

Foreach ($vm in $vmlist) 
{
   $memory = $vm.MemoryGB 
   $reservations = Get-VMResourceConfiguration $vm 
   $reservedmem = $reservations.MemReservationGB

   If ($memory -ne $reservedmem){
        Write-Host $vm $memory $reservedmem
        }

}
    