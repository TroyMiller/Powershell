$vmlist = Get-VM -name "Win*"

$totalmemory = 0
$totaluseddisk = 0
$totalprovdisk = 0
$totalcpu = 0
$vmcount = $vmlist.Count

Foreach ($vm in $vmlist) 
    {
   $totalcpu += $vm.NumCpu
   $totalmemory += $vm.MemoryGB
   $totaluseddisk += $vm.UsedSpaceGB
   $totalprovdisk += $vm.ProvisionedSpaceGB
   } 
write-host "Total VMs:" $vmcount
write-host "Total CPU:" $totalcpu
write-host "Total Memory (GB):"$totalmemory
write-host "Total Disk Used(GB):"$totaluseddisk
write-host "Total Disk Provisioned(GB):"$totalprovdisk