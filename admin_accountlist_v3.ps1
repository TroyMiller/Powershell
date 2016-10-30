$output = 'c:\output\administrators_list.csv' 
$results = @()
function Get-LocalGroupMembers {
<#
.Synopsis
   Get the group membership of a local group on the local or a remote computer
.EXAMPLE
   Defaults to collecting the members of the local Administrators group

    PS C:\> Get-LocalGroupMembers | ft -AutoSize

    ComputerName ParentGroup Nesting Name          Domain       Class
    ------------ ----------- ------- ----          ------       -----
    EricsComputer                   0 Administrator EricsComp    User 
    EricsComputer                   0 eric          EricsComp    User 
    EricsComputer                   0 Domain Admins DomainName   Group
.EXAMPLE
   Query a remote computer (that is known not to respond to a ping) and a targeted group

    PS C:\> Get-LocalGroupMembers -computerName EricsComputer -localgroupName Users -pingToEstablishUpDown $false

    ComputerName ParentGroup Nesting Name          Domain       Class
    ------------ ----------- ------- ----          ------       -----
    EricsComputer                   0 SomeOtherGuy  EricsComp    User 

.NOTES
   The ParentGroup and Nesting attributes in the output are present to allow
   the output of this function to be combined with the output of 
   Get-ADNestedGroupMembers.  They serve no purpose otherwise.
#>
    Param(
        $computerName = $env:computername,
        $localgroupName = "Administrators",
        $pingToEstablishUpDown = $true
    )
    $requestedComputerName = $computerName
    if ($computername = Resolve-DnsName $computername) {
        $computername = ($computername | where querytype -eq A).Name
        if ($computername -ne $requestedComputerName) {
            Write-Warning "Using name $computerName for $requestedComputerName"
        }
    } else {
        Write-Warning "Unable to resolve $requestedComputerName in DNS"
        return "" | select @{label="ComputerName";Expression={$requestedComputerName}},
                                        @{label="ParentGroup";Expression={""}},
                                        @{label="Nesting";Expression={""}},
                                        @{Label="Name";Expression={"ComputerName did not resolve in DNS"}},
                                        @{Label="Domain";Expression={"ComputerName did not resolve in DNS"}},
                                        @{Label="Class";Expression={"ComputerName did not resolve in DNS"}}
    }
    if ($pingToEstablishUpDown) {
        if (-not (Test-Connection -count 1 $computerName)) {
            Write-Warning "Unable to ping $computerName, aborting ADSI connection attempt"
            return "" | select @{label="ComputerName";Expression={$requestedComputerName}},
                                        @{label="ParentGroup";Expression={""}},
                                        @{label="Nesting";Expression={""}},
                                        @{Label="Name";Expression={"Not available to query"}},
                                        @{Label="Domain";Expression={"Not available to query"}},
                                        @{Label="Class";Expression={"Not available to query"}}
        }
    }
    try {
        if([ADSI]::Exists("WinNT://$computerName/$localGroupName,group")) {    
            $group = [ADSI]("WinNT://$computerName/$localGroupName,group")  
            $members = @()  
            $Group.Members() | foreach {
                $AdsPath = $_.GetType.Invoke().InvokeMember("Adspath", 'GetProperty', $null, $_, $null)
                # Domain members will have an ADSPath like WinNT://DomainName/UserName.  
                # Local accounts will have a value like WinNT://DomainName/ComputerName/UserName.  
                $a = $AdsPath.split('/',[StringSplitOptions]::RemoveEmptyEntries)
                $name = $a[-1]  
                $domain = $a[-2]  
                $class = $_.GetType.Invoke().InvokeMember("Class", 'GetProperty', $null, $_, $null)  

                $members += "" | select @{label="ComputerName";Expression={$computerName}},
                                        @{label="ParentGroup";Expression={""}},
                                        @{label="Nesting";Expression={0}},
                                        @{Label="Name";Expression={$name}},
                                        @{Label="Domain";Expression={$domain}},
                                        @{Label="Class";Expression={$class}}
            }    
        }  
        else {  
            Write-Warning "Local group '$localGroupName' doesn't exist on computer '$computerName'"  
        }
    }
    catch { 
        Write-Warning "Unable to connect to computer $computerName with ADSI"
        return $false }
    return ,$members
}
$computernames = Get-ADComputer -Filter {name -like "JMP*"} -properties Name | sort Name

foreach($computername in $computernames){
    $members = Get-LocalGroupMembers -computerName $computername.name -localgroupName Administrators -pingToEstablishUpDown $true
    $results += $members
}

$results | Export-csv $Output -NoTypeInformation