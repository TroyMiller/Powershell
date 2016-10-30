import-module ActiveDirectory
$servers = get-content 'C:\output\groups.txt'

foreach ($server in $servers)
{
set-ADGroup -id "gl-IT-$server-Admin" -Description "Admin on $server"
}