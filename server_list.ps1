
$servers = Get-ADComputer -Filter {operatingsystem -like "*server*"} -properties Name | sort Name 
$output = @()
ForEach ($server in $servers) {
   $results = Get-WMIObject -query "select StatusCode from Win32_PingStatus where Address = '$($server.name)'"
   $responds = $false  
   ForEach ($result in $results) {
      # If the machine responds break out of the result loop and indicate success
      if ($result.statuscode -eq 0) {
         $responds = $true
         Write-Output "$($server.name)"
         $Output += $($server.name)
         break
          }
   }
}
$output | out-file C:\output\servers.txt