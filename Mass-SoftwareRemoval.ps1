#Remove Microsoft Web Deploy 3.5
$servers = get-content 'C:\scripts\serverlist.txt'
$software = "Microsoft Web Deploy 3.5"
$scriptpath = 'C:\Scripts'
$arguments = "-Computername $server -Title $software"

foreach ($server in $servers)
{
    #Start-Job -FilePath "$scriptpath\Remove-SoftwareTitle.ps1 -Computername $server -Title $software -Prompt $false" -Verbose
    Invoke-Expression "$scriptpath\Remove-SoftwareTitle.ps1 -Computername $server -Title 'Microsoft Web Deploy 3.5'"
}