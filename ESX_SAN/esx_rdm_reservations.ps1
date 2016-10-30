$vmName = "jmpsql50a"

$vm = Get-VM -Name $vmName
$rdm = Get-HardDisk -DiskType rawPhysical -Vm $vm
$vmhosts = Get-Cluster -VM $vm | Get-VMHost
foreach($esx in $vmhosts){
  $esxcli = Get-EsxCli -VMHost $esx
  Foreach ($Disk in $rdm) {
  $esxcli.storage.core.device.list($disk.ScsiCanonicalName) | Select DisplayName,Device,IsPerenniallyReserved
  $esxcli.storage.core.device.setconfig($false,$disk.ScsiCanonicalName,$true)
  $esxcli.storage.core.device.list($disk.ScsiCanonicalName) | Select DisplayName,Device,IsPerenniallyReserved
  }
}