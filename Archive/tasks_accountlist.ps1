Import-module ActiveDirectory
$domain = "jewelersnt*"

$servers = Get-ADComputer -Filter {operatingsystem -like "*server*"} -properties Name,DNSHostname | sort Name
$Output = @()

ForEach ($server in $servers) {
   # Ping the machine to see if it's on the network
   $results = Get-WMIObject -query "select StatusCode from Win32_PingStatus where Address = '$($server.name)'"
   $responds = $false  
   ForEach ($result in $results) {
      # If the machine responds break out of the result loop and indicate success
      if ($result.statuscode -eq 0) {
         $responds = $true
         break
      }
   }
         If ($responds) {
      # Gather info from the server because it responds
      $schtask = schtasks.exe /query /s $server.Name /V /FO CSV | ConvertFrom-Csv | Where { $_.TaskName -ne "TaskName" }
      $services = $schtask | where { $_."Run As User" -like "$domain"} 
      $Output += $Services
   } else {
      # Let the user know we couldn't connect to the server
      Write-Output "$($server.name) does not respond"
   }
}
$Output | export-csv c:\Scripts\task_accounts.csv
