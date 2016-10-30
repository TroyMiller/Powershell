import-module ActiveDirectory
$servers = get-content 'C:\scripts\servers.txt'

foreach ($server in $servers)
{
	New-ADGroup -Name "gl-IT-$server-Admin" -path "ou=Production,ou=Servers,ou=Security Groups,dc=jewelersnt,dc=local" -groupScop DomainLocal -Description "Admin on $server"
}