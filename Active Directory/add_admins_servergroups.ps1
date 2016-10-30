import-module ActiveDirectory
$filepath = 'C:\output\test_administrators_list.csv'
$serverlist = Import-Csv $filepath

Foreach ($server in $serverlist) 
{
$group = $server.server
$members = $server.admin
add-adgroupmember -id "gl-IT-$group-admin" -members "$members"
}