#Replace with the old suffix
$oldSuffix = 'jewelersnt.local'

#Replace with the new suffix
$newSuffix = 'jminsure.com'

#Replace with the OU you want to change suffixes for
#$ou = "DC=sample,DC=domain"

#Replace with the name of your AD server
#$server = "test"
Start-Transcript -path c:\output\upnupdate.log -Append
Get-ADUser -LDAPFilter "(&(objectCategory=user)(objectClass=user)(manager=*)(title=*))" | ForEach-Object {
$newUpn = $_.UserPrincipalName.Replace($oldSuffix,$newSuffix)
$_ | Set-ADUser -UserPrincipalName $newUpn
Write-host "UPN set for $newUpn"
}
Stop-Transcript