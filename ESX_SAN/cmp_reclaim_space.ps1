connect-viserver -Server "jmpvcr02.jewelersnt.local"
$esxcli = Get-EsxCli -VMHost "jmpvmw59.jewelersnt.local"
$datastores = get-datastore | where {$_.name -like "4020_VDI_*"}

foreach ($datastore in $datastores) {
    write-host "Unmapping $datastore"
    $esxcli.storage.vmfs.unmap(800, $datastore.Name, $null)
    }