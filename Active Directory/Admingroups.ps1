import-module ActiveDirectory
$servers = get-content 'C:\scripts\test_serverlist.txt'

foreach ($server in $servers)
{
write-host set-ADGroup -Name "gl-IT-$server-Admin" -Description "Admin on $server"
}