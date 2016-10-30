$vcenter = "jmpvcr01.jewelersnt.local"
$cluster = "JMDEV01"

connect-viserver -Server $vcenter
$servers = get-cluster $cluster | get-vmhost | select name

foreach($server in $servers){
    $esxcli=get-esxcli -VMHost "jmdvmw19.jewelersnt.local"
    $xtremluns = $esxcli.storage.core.device.list() | where { $_.Vendor -eq "XtremIO"}
    
    foreach($xtremlun in $xtremluns) {
        write-host $xtremlun.DisplayName
        write-host $xtremlun.Device
        $esxcli.storage.core.device.set($null, $xtremlun.device, $null, $null, $null, $null, $null, 256, $null)
        #$esxcli.storage.core.device.list($xtremlun.device)
    }
}

$EsxHosts = get-cluster $cluster | get-vmhost
foreach ($esx in $EsxHosts)
{
$esxcli = Get-EsxCli -VMHost $esx
$devices = $esxcli.storage.core.device.list()
foreach ($device in $devices)
{
if ($device.Model -like “XtremApp”)
    {
    $esxcli.storage.core.device.set($false, $null, $device.Device, $null, $null, $null, $null, $null, $null, $null, $null, ‘256’,$null,$null)
    $esxcli.storage.core.device.list()
    }
}
}