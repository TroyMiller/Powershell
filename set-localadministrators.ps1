import-module ActiveDirectory
$servers = get-content 'C:\Output\prod-servers.txt'

foreach ($server in $servers)
{
	Invoke-Expression "C:\scripts\Set-ADAccountasLocalAdministrator.ps1 -Computer $server -Trustee jewelersnt\gl-IT-$server-Admin"
}