$vmName = "jmpsql50b"

$vm = Get-VM -Name $vmName
$rdm = "naa.60060160b6d035009b9543c9f80ce411","naa.60060160b6d035003a3996daf80ce411","naa.60060160b6d035006bba8aecf80ce411","naa.60060160b6d03500ccac0bfff80ce411","naa.60060160b6d03500044f3911f90ce411","naa.60060160b6d0350054159334fd0ce411","naa.60060160b6d03500c9e9a846fd0ce411","naa.60060160b6d035004b003159fd0ce411","naa.60060160b6d035001373c069fd0ce411","naa.60060160b6d035009e36ab7dfd0ce411","naa.60060160b6d03500a464ed97fd0ce411","naa.60060160b6d03500ef6d20affd0ce411","naa.60060160b6d0350073258fe5fd0ce411","naa.60060160b6d03500daa1faa5fe0ce411","naa.60060160b6d0350016e1ebbffe0ce411","naa.60060160b6d03500b49b28f6fe0ce411","naa.60060160b6d03500715a9c09ff0ce411","naa.60060160b6d03500d34c1d1cff0ce411","naa.60060160b6d03500461a7a32ff0ce411","naa.60060160b6d03500b2412d43ff0ce411","naa.60060160b6d03500f9b32359ff0ce411","naa.60060160b6d03500bb8aea6eff0ce411","naa.60060160b6d03500305f0081ff0ce411","naa.60060160b6d035001977ad92ff0ce411","naa.60060160b6d03500b58ed6a2ff0ce411","naa.60060160b6d035008bdb3a361f0de411"
$vmhosts = Get-Cluster -VM $vm | Get-VMHost
foreach($esx in $vmhosts){
  $esxcli = Get-EsxCli -VMHost $esx
  Foreach ($Disk in $rdm) {
  $esxcli.storage.core.device.list($disk) | Select DisplayName,Device,IsPerenniallyReserved
  #$esxcli.storage.core.device.setconfig($false,$disk,$true)
  #$esxcli.storage.core.device.list($disk) | Select DisplayName,Device,IsPerenniallyReserved
  }
}