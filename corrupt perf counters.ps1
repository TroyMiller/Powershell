
$strComputers = Get-ADComputer -Filter {name -like "xd*"} -properties Name,DNSHostname | sort Name
$Output = @()

ForEach ($strComputer in $strComputers) {

  # Ping the machine to see if it's on the network
   $results = Get-WMIObject -query "select StatusCode from Win32_PingStatus where Address = '$($strComputer.name)'"
   $responds = $false  
   ForEach ($result in $results) {
      # If the machine responds break out of the result loop and indicate success
      if ($result.statuscode -eq 0) {
         $responds = $true
         break
      }
   }
      If ($responds) {
      # Gather info from the computer because it responds
        $strKeyPath = "SOFTWARE\Microsoft\Windows NT\CurrentVersion\Perflib\009"
        $strValueName2 = 'Counter' 
        $reg = Get-WmiObject -List -Namespace root\default -ComputerName $strComputer.name | Where-Object {$_.Name -eq "StdRegProv"}
        $strValue2 = $reg.GetMultiStringValue(2147483650,$strKeyPath,$strValueName2)
        
        if ($strValue2.sValue -eq $null)
            {
            Write-Output "$($strComputer.name) - Value Not Found"
            }
        if ($strValue2.sValue[0] -eq '' -or $strValue2.sValue[0] -eq $null)
            {
            Write-Output "$($strComputer.name), Corrupt Perflib Counters"
            }
        else { Write-Output "$($strComputer.name), the first row is $($strValue2.sValue[0])" }

   } else {
      # Let the user know we couldn't connect to the server
      Write-Output "$($strComputer.name), does not respond"
   }
}
