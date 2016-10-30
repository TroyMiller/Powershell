$hosts = get-vmhost -name jmd*
foreach ($esx in $hosts)
{
$esxcli=get-esxcli -VMHost $esx
$esxcli.storage.nmp.satp.rule.add($null, $null, "PURE FlashArray RR IO Operation Limit Rule", $null, $null, $null, "FlashArray", $null, "VMW_PSP_RR", "iops=1", "VMW_SATP_ALUA", $null, $null, "PURE")
}