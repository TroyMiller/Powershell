$hosts = get-vmhost -name jmd*
foreach ($esx in $hosts)
{
$esxcli=get-esxcli -VMHost $esx
$esx | Get-AdvancedSetting -Name DataMover.MaxHWTransferSize | Set-AdvancedSetting -Value 16384 -Confirm:$false
}