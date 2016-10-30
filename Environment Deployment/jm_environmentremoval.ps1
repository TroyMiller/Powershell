#Clean-up env

$ScriptRoot = Split-Path $MyInvocation.MyCommand.Path
$StartTime = Get-Date -Format "yyyyMMddHHmmss_"
$logdir = $ScriptRoot + "\PureRefreshLogs\"
$logfilename = $logdir + $StartTime + "purerefresh.log"
$csvfile = $ScriptRoot + "\" + "vms2deploy.csv"
$VIServerName = 'jmpvcr01.jewelersnt.local'
$HostGroupName = 'JMDEV01'
$domain = '.jewelersnt.local'
$servers = @()
$servers = import-csv $csvfile
$puppetmaster = "puppet.jewelersnt.local"

#Credentials used to invoke commands on servers
if ($admincreds -eq $null)
{
    $admincreds = Get-Credential -Message "Enter Admin Credentials for AD and VMware"
}

#Get Puppet Master SSH login
If ($ssh_cred -eq $null)
{
    $ssh_cred = Get-Credential -Message "SSH login for $puppetmaster"
}


Function Write-and-Log ($Message)
{
    $message = (Get-Date -Format ("[yyyy-MM-dd HH:mm:ss] ")) + $message
    Write-Verbose "$message" -Verbose
    (Get-Date -Format ("[yyyy-MM-dd HH:mm:ss] ")) + "$message" | out-file $logfilename -Append
}


#############################
#Load Powershell Modules
#############################

#load AD module
Import-Module ActiveDirectory

#Load Posh-SSH module
import-module Posh-SSH

#load PowerCLI snap-in
$vmsnapin = Get-PSSnapin VMware.VimAutomation.Core -ErrorAction SilentlyContinue
$Error.Clear()
if ($vmsnapin -eq $null) {
	Add-PSSnapin VMware.VimAutomation.Core
	if ($error.Count -eq 0) {
		write-and-log $logfilename "PowerCLI VimAutomation.Core Snap-in was successfully enabled." 0 "terse"
	}
	else{
		write-and-log $logfilename "Could not enable PowerCLI VimAutomation.Core Snap-in, exiting script" 1 "terse"
		Exit
	}
}
else{
	write-and-log $logfilename "PowerCLI VimAutomation.Core Snap-in is already enabled" 0 "terse"
}
#############################
#Load Powershell Modules
#############################

#Connect to vCenter
connect-viserver -Server $VIServerName -Credential $admincreds
#Connect to Puppet
New-SSHSession -ComputerName $puppetmaster -Credential $ssh_cred


Foreach ($server in $servers)
{
    $serverfqdn = $server.name + $domain

    ###Remove Groups
    If (get-adgroup -Filter {SamAccountName -eq "gl-IT-$($server.name)-Admin"} )
    {   
        Write-and-log ":Info: Removing gl-IT-$($server.name)-Admin group" 
        Remove-ADGroup -id "gl-IT-$($server.name)-Admin" -Credential $admincreds -Confirm:$false
    }

    ###Remove Computers
    If (get-adcomputer -Filter {Name -eq "$($server.name)"})
    {
        Write-and-log ":Info: Removing $($server.name)"
        Remove-ADComputer $server.Name -Credential $admincreds -Confirm:$false
    }
    
    #Removes Service Accounts for SQL servers
    If ($server.name -like '*SQL*')
    {
        #Grab for SQL groups
        $server_num = $server.name.Substring($server.name.Length - 6,6)

        $svcaccount_name_eng = "svc-" + $server_num + "-eng" 
        $svcaccount_name_agt = "svc-" + $server_num + "-agt"

        Write-and-log ":Info: Removing $svcaccount_name_eng"
        Remove-ADUser $svcaccount_name_eng -Credential $admincreds -Confirm $false
        Write-and-log ":Info: Removing $svcaccount_name_agt"
        Remove-ADUser $svcaccount_name_agt -Credential $admincreds -Confirm $false
    }

    ###Remove Puppet Cert
    Write-and-log ":Info: Removing puppet cert for $serverfqdn"
    Invoke-SSHCommand -SessionId 0 -Command "sudo puppet cert clean $serverfqdn"
    Invoke-SSHCommand -SessionId 0 -Command "sudo puppet node purge $serverfqdn"


    ###Poweroff VM
    If (get-vm | where {$_.name -eq $($server.name)})
    {
        Write-and-log ":Info: Stop VM $($server.name)" 
        Stop-VM $server.name -Confirm:$false -RunAsync
    }

    ###Remove VM
    If (get-vm | where {$_.name -eq $($server.name)})
    {
        Write-and-log ":Info: Removing VM $($server.name)" 
        Remove-VM $server.name -DeletePermanently -Confirm:$false -RunAsync
    }
}
Get-SSHSession | Remove-SSHSession


$vmhost = get-vmhost -location $HostGroupName -State Connected | select -First 1
$esxcli = Get-EsxCli -VMHost $vmhost
$datastores = get-datastore | where {$_.name -like "PureM01_VM_SRV*"}

foreach ($datastore in $datastores) 
{
    write-and-log "Running unmap $datastore"
    $esxcli.storage.vmfs.unmap(2048, $datastore.Name, $null)
   
}

Disconnect-VIServer -server $VIServerName -Confirm:$false