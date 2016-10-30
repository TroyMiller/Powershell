#requires -version 2

<#
.SYNOPSIS
    
    Script automates deployment of multiple vms loaded from pre-defined .csv file 

.DESCRIPTION

    Script reads input from .csv file (that needs to be saved in script's working directory, under the name of "vms2deploy.csv")
    Script will return an error if the file is not found in working directory.
    After rudimentary input sanitization (removing lines with empty fields) a separate background job (process) is started for
    each unique host cluster found in input. 
    The scriptblock that defines background job takes care of asynchronous creation of requested VMs (clone from template). 
    To not overload the cluster number of VMs being deployed at any given moment is smaller than number of active vmhosts in cluster. 
    After VM is deployed scriptblock powers it on to start OS Customization process.
    Last part of deploy scriptblock is to search vCenter events for successful or failed customization completions.
    Background job exits when all powered on VMs completed OS Customization (no matter successfully or not) or when pre-defined 
    time-out elapses.
    Requires Posh-SSH, ActiveDirectory, and PowerCLI modules be installed

.PARAMETER vCenterServer

    Mandatory parameter indicating vCenter server to connect to (FQDN or IP address)
   
.EXAMPLE

    ultimate_deploy.ps1 -vCenterServer vcenter.seba.local
    
    vCenter Server indicated as FQDN
    
.EXAMPLE

    ultimate_deploy.ps1 -vcenter 10.0.0.1
    
    vCenter Server indicated as IP address   
    
.EXAMPLE

    ultimate_deploy.ps1
    
    Script will interactively ask for mandatory vCenterServer parameter
 
#>

#[CmdletBinding()]
#Param(
#   [Parameter(Mandatory=$True,Position=1)]
#   [ValidateNotNullOrEmpty()]
#   [string]$vCenterServer
#)


Function Write-And-Log {

[CmdletBinding()]
Param(
   [Parameter(Mandatory=$True,Position=1)]
   [ValidateNotNullOrEmpty()]
   [string]$LogFile,
	
   [Parameter(Mandatory=$True,Position=2)]
   [ValidateNotNullOrEmpty()]
   [string]$line,

   [Parameter(Mandatory=$False,Position=3)]
   [int]$Severity=0,

   [Parameter(Mandatory=$False,Position=4)]
   [string]$type="terse"

   
)

$timestamp = (Get-Date -Format ("[yyyy-MM-dd HH:mm:ss] "))
$ui = (Get-Host).UI.RawUI


switch ($Severity) {

        {$_ -gt 0} {$ui.ForegroundColor = "red"; $type ="full"; $LogEntry = $timestamp + ":Error: " + $line; break;}
        {$_ -eq 0} {$ui.ForegroundColor = "green"; $LogEntry = $timestamp + ":Info: " + $line; break;}
        {$_ -lt 0} {$ui.ForegroundColor = "yellow"; $LogEntry = $timestamp + ":Warning: " + $line; break;}

}
switch ($type) {
   
        "terse"   {Write-Output $LogEntry; break;}
        "full"    {Write-Output $LogEntry; $LogEntry | Out-file $LogFile -Append; break;}
        "logonly" {$LogEntry | Out-file $LogFile -Append; break;}
     
}

$ui.ForegroundColor = "white" 

}

#Variables used in Deployment
$ScriptRoot = Split-Path $MyInvocation.MyCommand.Path
$StartTime = Get-Date -Format "yyyyMMddHHmmss_"
$csvfile = $ScriptRoot + "\" + "vms2deploy.csv"
$logdir = $ScriptRoot + "\UltimateDeployLogs\"
$transcriptfilename = $logdir + $StartTime + "ultimate-deploy_Transcript.log"
$logfilename = $logdir + $StartTime + "ultimate-deploy.log"
$chocolateyserver = "jmpchy01.jewelersnt.local"
$puppetmaster = "puppet.jewelersnt.local"
$jobs_tab = $null
$maxcount = 15
$sleeptime = 10
$vCenterServer = "jmpvcr01.jewelersnt.local"
$SQLServerAdmins = @('SQLAdmins', 'GG-SQLAdmins-TestDev', 'svc-solarwinds-sql')
$svc_account_path = 'OU=Special,OU=Information Technology,OU=JMIC,DC=jewelersnt,DC=local'
$sql_service_account_group = 'GG-SQLSVCACCTS-All'

#Puppet Version
$version = '1.5.3'
$puppetfilename = "puppet-agent-$version-x64.msi"

#Downloads Puppet Version to Internal webserver
$source = "https://downloads.puppetlabs.com/windows/$puppetfilename"
$destination = "\\$chocolateyserver\Apps\puppet_agent\$puppetfilename"

#Configures Download Locations for Puppet Install
$puppetsource = "http://$chocolateyserver/Apps/puppet_agent/$puppetfilename"
$puppetdownload = "c:\temp\$puppetfilename"

#initializing counters
[int]$total_vms = 0 
[int]$processed_vms = 0
[int]$total_clusters = 0
[int]$total_errors = 0
[int]$total_dplfail = 0
[int]$total_pwrok = 0
[int]$total_pwrfail = 0
[int]$total_custstart = 0
[int]$total_custok = 0
[int]$total_custfail = 0

#test for log directory, create if needed
if ( -not (Test-Path $logdir)) {
			New-Item -type directory -path $logdir | out-null
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
#End Load Powershell Modules
#############################




###################################
#Script Block that Builds VMs
###################################
. .\jm_ultimate_deploy_vmdeploy_scriptblock.ps1
###################################
#End of Script Block that Builds VMs
###################################



if ($true) {#if ($env:Processor_Architecture -eq "x86") { #32-bit is required for OS Customization Spec related cmdlets
	
	if (($vmsnapin.Version.Major -gt 5) -or (($vmsnapin.version.major -eq 5) -and ($vmsnapin.version.minor -ge 5))) { #check PowerCLI version
			
		#assume everything is OK at this point
		$Error.Clear()
	
		#sanitize input a little
		$vms2deploy = Import-Csv -Path $csvfile
		$vms2deploy = $vms2deploy | where-object {($_.name -ne "") -and ($_.template -ne "") -and ($_.oscust -ne "") -and ($_.cluster -ne "")} | sort-object name -unique
		$total_vms = $vms2deploy.count
	
		#anything still there - let's deploy!
		if ($vms2deploy) {
			
			#we will start one background job per unique cluster listed in .csv file
			$host_clusters = $vms2deploy | sort-object cluster -unique | select-object cluster
			$total_clusters = $host_clusters.count
		
			#connect vCenter from parameter, we need to save credentials, to pass them to background jobs later on
			$credentials = $Host.UI.PromptForCredential("vCenter authentication dialog","Please provide credentials for $vCenterServer", "", "")
            
            #Get Puppet Master SSH login
            If ($ssh_cred -eq $null)
            {
                $ssh_cred = Get-Credential -Message "SSH login for $puppetmaster"
            }
			Connect-VIServer -Server $vCenterServer -Credential $credentials -ErrorAction SilentlyContinue | Out-Null

			#execute only if connection successful
			if ($error.Count -eq 0){
	    
				#use previously defined function to inform what is going on, anything else than "terse" will cause the message to be written both in logfile and to screen
				Write-And-Log $logfilename "vCenter $vCenterServer successfully connected" $error.count "terse"
						
				#measuring execution time is really hip these days
				$stop_watch = [Diagnostics.Stopwatch]::StartNew()
			
				#fire a background job for each unique cluster
                foreach ($cluster in $host_clusters) {
						$vms_in_cluster = $vms2deploy | where-object { $_.cluster -eq $cluster.cluster }
						$logfile = $logdir + $StartTime + $cluster.cluster + "-DeployJob.log"
						$progressfile = $logdir + $cluster.cluster + "-progress.csv"
						Write-And-Log $logfilename "Dispatching background deployment job for cluster $($cluster.cluster)" 0 "full"
						$jobs_tab += @{ $cluster.cluster = start-job -name $cluster.cluster -scriptblock $deploy_VMs_scriptblock -argumentlist $vCenterServer, $credentials, $vms_in_cluster, $logfile, $progressfile }
				}
				
                #track the job progress + "ornaments"
				do{
					#do not repeat too often
					Start-Sleep -Seconds 20
                    Write-And-Log $logfilename "Pooling background deployment jobs" -1
					$running_jobs = 0
                    $total_pwrok = 0
                    $total_dplfail = 0
					$total_pwrfail = 0
					$total_custstart = 0
					$total_custok = 0
					$total_custfail = 0

					foreach ($cluster in $host_clusters){
						if ($($jobs_tab.Get_Item($cluster.cluster)).state -eq "running") {
							$running_jobs++
						}
										
						$progressfile = $logdir +$cluster.cluster + "-progress.csv"
						$jobs_progress = Import-Csv -Path $progressfile
						$total_pwrok += $jobs_progress.PWROK
                        $total_dplfail += $jobs_progress.DPLFAIL
						$total_pwrfail += $jobs_progress.PWRFAIL
						$total_custstart += $jobs_progress.CUSTSTART
						$total_custok += $jobs_progress.CUSTOK
						$total_custfail += $jobs_progress.CUSTFAIL
					}
					
					#display different progress bar depending on stage we are at (if any customization started, show customization progress, in this way we always show "worst case" progress)
					if ($total_custstart){
						$processed_vms = $total_custok + $total_custfail
						write-progress -Activity "$running_jobs background deployment jobs in progress" -Status "Percent complete $("{0:N2}" -f (($processed_vms / $total_pwrok) * 100))%" -PercentComplete (($processed_vms / $total_vms) * 100) -CurrentOperation "VM OS customization in progress"
					}
					else {
						$processed_vms = $total_pwrok + $total_pwrfail + $total_dplfail
						write-progress -Activity "$running_jobs background deployment jobs in progress" -Status "Percent complete $("{0:N2}" -f (($processed_vms / $total_vms) * 100))%" -PercentComplete (($processed_vms / $total_vms) * 100) -CurrentOperation "VM deployment in progress"
					}
										
					Write-And-Log $logfilename "Out of total $total_vms VM deploy requests there are $total_pwrok VMs successfully powered on, $($total_pwrfail + $total_dplfail) failed." $($total_pwrfail + $total_dplfail) "full"
					Write-And-Log $logfilename "Out of total $total_pwrok successfully powered on VMs OS Customization has started for $total_custstart VMs, succeeded for $total_custok VMs, failed for $total_custfail." $total_custfail "full"
					
                    
				#until we are out of active jobs
                } until ($running_jobs -eq 0)
				
				#time!
				$stop_watch.Stop()
				$elapsed_seconds = ($stop_watch.elapsedmilliseconds)/1000
				$total_errors = $total_pwrfail + $total_custfail + $total_dplfail
				
                #farewell message before disconnect
				Write-And-Log $logfilename "Out of total $total_vms VM deploy requests $total_pwrok VMs were successfully powered on, $($total_pwrfail + $total_dplfail) failed, $($total_vms - $total_pwrok - $total_pwrfail - $total_dplfail) duplicate VM names were detected (not deployed)." $($total_pwrfail + $total_dplfail) "full"
				Write-And-Log $logfilename "Out of total $total_pwrok successfully powered on VMs OS Customization has been successful for $total_custok VMs, failed for $total_custfail." $total_custfail "full"
				Write-And-Log $logfilename "$($host_clusters.count) background deployment jobs completed in $("{0:N2}" -f $elapsed_seconds)s, $total_errors ERRORs reported, exiting." $total_errors "full"	

				
			}
			else{
			Write-And-Log $logfilename "Error connecting vCenter server $vCenterServer, exiting" $error.count "full"
			}
		}
		else {
			Write-And-Log $logfilename "Invalid input in $csvfile file, exiting" 1 "full"
		}
	}	
	else {
		write-and-log $logfilename "This script requires PowerCLI 5.5 or greater to run properly" 1 "full"
	}
}
else {
	write-and-log $logfilename "This script should be run from 32-bit version of PowerCLI only, Open 32-bit PowerCLI window and start again" 1 "full"
}



#Too lazy to redo all the variables
#This just uses the vms2deploy for installing puppet and AD work
$servers = @()
$servers = $vms2deploy

Foreach($server in $servers){
    #Convert server name to string for manipulating
    [string]$servername = $server.Name

    #Ignore first 3 digits, select last 3 as $role ex:(JMTAPP01 = APP, JMDSQL01 = SQL)
    $role = $servername.Substring(3,3)

    #Ignore first 2 digits, select next as environment ex:(JMT = t, JMP = p)
    $env = $servername.Substring(2,1)
    


    #Determines environment setting based on 3rd letter of server name
    switch ($env) 
    { 
        "d" {$env = "DEV"} 
        "t" {$env = "TEST"} 
        "s" {$env = "STAGE"} 
        "p" {$env = "PROD"}
        default {"No environment set"; exit;}
    }
    write-host "$($server.name) belongs in $env"
    
    #Top Level Search
    $admin_group_path = Get-ADOrganizationalUnit -Filter * -SearchScope 1 | where {$_.name -eq "Security Groups"}
    #Find Server OU under Security Groups
    $admin_group_path = Get-ADOrganizationalUnit -Filter * -SearchBase $admin_group_path -SearchScope 1 | where {$_.name -eq "Servers"}
    #Find envrionment under Security Groups\Server
    $admin_group_path = Get-ADOrganizationalUnit -filter * -SearchBase $admin_group_path -SearchScope 1 | Where {$_.name -eq $env}

    if (!(Get-ADGroup -filter * -searchbase $admin_group_path | where {$_.name -eq "gl-IT-$($server.name)-Admin"})){
        
        #Creates Admin Group for individual server
        (Get-Date -Format ("[yyyy-MM-dd HH:mm:ss] ")) + ":Info: Creating gl-IT-$($server.name)-Admin group @ $admin_group_path" | out-file $logfilename -Append
        New-ADGroup -Name "gl-IT-$($server.name)-Admin" -path $admin_group_path -groupScop DomainLocal -Description "Admin on $($server.name)" -Credential $credentials
    }

    
    #Sets Admins for SQL servers
    If ($server.name -like '*SQL*')
    {
        #Grab for SQL groups
        $server_num = $server.name.Substring($server.name.Length - 6,6)

        $svcaccount_name_eng = "svc-" + $server_num + "-eng" 
        $svcaccount_name_agt = "svc-" + $server_num + "-agt"

        (Get-Date -Format ("[yyyy-MM-dd HH:mm:ss] ")) + ":Info: Adding SQL Admin groups to gl-IT-$($server.name)-Admin group" | out-file $logfilename -Append
        Add-AdGroupmember -Identity "gl-IT-$($server.name)-Admin" -Members $SQLServerAdmins -Credential $credentials
        
        (Get-Date -Format ("[yyyy-MM-dd HH:mm:ss] ")) + ":Info: SQL Creating service account: $svcaccount_name_eng" | out-file $logfilename -Append
        New-ADUser -DisplayName $svcaccount_name_eng -Name $svcaccount_name_eng -AccountPassword (ConvertTo-SecureString "P@ssw0rd!" -AsPlainText -Force) -Enabled $true -CannotChangePassword $true -ChangePasswordAtLogon $false -PasswordNeverExpires $true -Description "SQL service account for $($server.name)" -Path $svc_account_path -Credential $credentials
        (Get-Date -Format ("[yyyy-MM-dd HH:mm:ss] ")) + ":Info: SQL Creating service account: $svcaccount_name_agt" | out-file $logfilename -Append
        New-ADUser -DisplayName $svcaccount_name_agt -Name $svcaccount_name_agt -AccountPassword (ConvertTo-SecureString "P@ssw0rd!" -AsPlainText -Force) -Enabled $true -CannotChangePassword $true -ChangePasswordAtLogon $false -PasswordNeverExpires $true -Description "SQL service account for $($server.name)" -Path $svc_account_path -Credential $credentials

        (Get-Date -Format ("[yyyy-MM-dd HH:mm:ss] ")) + ":Info: Adding SQL service accounts: $svcaccount_name_eng,$svcaccount_name_agt to $sql_service_account_group" | out-file $logfilename -Append
        Add-AdGroupmember -Identity $sql_service_account_group -Members $svcaccount_name_eng,$svcaccount_name_agt -Credential $credentials

    }

    
    #Top Level Search for Server OU
    $server_path = Get-ADOrganizationalUnit -filter * -SearchScope 1 | Where {$_.name -eq "Servers"}
    #Search for Environment within Servers OU
    $env_path = Get-ADOrganizationalUnit -filter * -SearchBase $server_path -SearchScope 1 | Where {$_.name -eq $env}
    #Search for Role OU within Servers\Env OU structure
    $role_path = Get-ADOrganizationalUnit -filter * -SearchBase $env_path -SearchScope 1 | Where {$_.name -eq $role}

    #Moves AD Computer object to correct OU
    (Get-Date -Format ("[yyyy-MM-dd HH:mm:ss] ")) + ":Info: Moving $($server.name) to $role_path" | out-file $logfilename -Append
    Get-ADComputer $server.Name | Move-ADObject -TargetPath $role_path -Credential $credentials
}

#Waiting for server to come up after customization completed, DNS to be updated
Sleep -Seconds 180
Foreach($server in $servers)
{
    $success = $false
    $count = 0

    While ($success -eq $false) 
    {
        if (Test-Connection -computer $server.name -ErrorAction SilentlyContinue) 
        {
            $success = $true
            $time = Get-Date
            Write-host "$($Server.name) Online - $time"
            (Get-Date -Format ("[yyyy-MM-dd HH:mm:ss] ")) + ":Info: $($server.name) to is online" | out-file $logfilename -Append
        }
        else 
        {
            $time = Get-Date
            Write-host "$($Server.name) Offline - $time, attempt $count of $maxcount"
            (Get-Date -Format ("[yyyy-MM-dd HH:mm:ss] ")) + ":Info: $($server.name) to is offline, attempt $count of $maxcount" | out-file $logfilename -Append
            $count++
            if ($count -igt $maxcount) 
            {
                read-host -prompt "***ERROR*** $($server.name) offline for too long!  Please check for issue manually before continuing."
                $success = $true
            }

            sleep ($sleeptime)

        }
    }
}

#Scriptblock that changes CD drive letter, formats second drive, and Extends partitions
$format_extend_drives_scriptblock = {
    #Set CDRom to Z:
    (gwmi Win32_cdromdrive).drive | %{$a = mountvol $_ /l;mountvol $_ /d;$a = $a.Trim();mountvol z: $a}
    
    #Formats drives with no partitions, sets to D:
    [int]$drivecount = '1'
    foreach ($disk in get-wmiobject Win32_DiskDrive -Filter "Partitions = 0" | sort){ 
       Switch ($drivecount) 
       {
            1 {$driveletter = 'D'}
            2 {$driveletter = 'Y'}
            3 {$driveletter = 'E'}
            default {"No additional drives configured";exit;}
       }
      
       $disk.DeviceID
       $disk.Index
       "select disk "+$disk.Index+"`r attributes disk clear readonly`r online disk`r convert mbr`r clean`r create partition primary`r format fs=ntfs unit=65536 quick`r active`r assign letter=$driveletter" | diskpart
       $drivecount++
    }

    #Extends partition on all disks
    'list disk' | diskpart | ? {
      $_ -match 'disk (\d+)\s+online\s+\d+ .?b\s+\d+ [gm]b'
    } | % {
      $disk = $matches[1]
      "select disk $disk", "list partition" | diskpart | ? {
        $_ -match 'partition (\d+)'
      } | % { $matches[1] } | % {
        "select disk $disk", "select partition $_", "extend" | diskpart | Out-Null
      }
    }
}

Foreach ($server in $servers){
    Write-Verbose "Set CDRom to Z:, Format new drives, Extend Partitions on $($server.Name)" -Verbose 
    If(Test-Connection -count 2 -computer $server.Name){
        New-PSSession -ComputerName $server.Name -Credential $credentials
        
        #ExecuteUpgrade on remote server
        (Get-Date -Format ("[yyyy-MM-dd HH:mm:ss] ")) + ":Info: Windows Disk Updates $($server.name)" | out-file $logfilename -Append
        Invoke-Command -ComputerName $server.Name -ScriptBlock $format_extend_drives_scriptblock -AsJob -Credential $credentials
    }
}
Get-Job | Wait-Job
Write-Verbose "Finished Windows Drive Changes" -Verbose



#Check if puppet install needs to be downloaded
if(!(Test-Path $destination)){
    (Get-Date -Format ("[yyyy-MM-dd HH:mm:ss] ")) + ":Info: Downloading File from $source to $destination" | out-file $logfilename -Append
    Invoke-WebRequest $source -OutFile $destination
}
else {
    (Get-Date -Format ("[yyyy-MM-dd HH:mm:ss] ")) + ":Info: $destination already exists" | out-file $logfilename -Append
}





#Script block for installing puppet on multiple servers at a time
$deploy_puppet_scriptBlock = {
    param ($puppetsource, $puppetdownload, $puppetmaster)

    #Removes file if it already exists
    if (Test-Path $puppetdownload) {Remove-Item -path $puppetdownload -Force}

    #Make temp directory for install
    if(!(test-path c:\temp)){ New-Item c:\temp -type directory}

    #Download Puppet Agent to C:\temp
    $client = New-Object System.Net.WebClient
    $client.DownloadFile($puppetsource,$puppetdownload)

    #Invoke-WebRequest $puppetsource -OutFile $puppetdownload
    #Above command requires PS3.0 or greater

    Start-Process -FilePath "msiexec.exe" -ArgumentList "/i $puppetdownload /qn /norestart PUPPET_MASTER_SERVER=$puppetmaster" -wait
}


Foreach ($server in $servers){
    Write-Verbose "Deploying Puppet Agent upgrade to $($server.Name)" -Verbose
    If(Test-Connection -count 2 -computer $server.Name){
        New-PSSession -ComputerName $server.Name -Credential $credentials
        
        #ExecuteUpgrade on remote server
        (Get-Date -Format ("[yyyy-MM-dd HH:mm:ss] ")) + ":Info: Deploying Puppet Agent to $($server.name)" | out-file $logfilename -Append
        Invoke-Command -ComputerName $server.Name -ScriptBlock $deploy_puppet_scriptblock -ArgumentList $puppetsource, $puppetdownload, $puppetmaster -AsJob -Credential $credentials
    }
}
Get-Job | Wait-Job
Write-Verbose "All Agents Upgraded" -Verbose


foreach ($server in $servers){
    Write-Verbose "Starting service on $($server.Name)" -Verbose
    (Get-Date -Format ("[yyyy-MM-dd HH:mm:ss] ")) + ":Info: Starting Puppet Agent on $($server.name)" | out-file $logfilename -Append
    Invoke-Command -ComputerName $server.Name -ScriptBlock {Start-Service -name puppet -Verbose} -Credential $credentials

    #Replace with delete file
    Invoke-Command -ComputerName $server.Name -ScriptBlock {param ($puppetdownload);Remove-Item -path $puppetdownload -Force} -ArgumentList $puppetdownload -Credential $credentials

}

#Get all job results
#Get-Job | Receive-Job | out-file $logfilename -Append

#Clean-up Jobs
Get-Job | Remove-Job

#disconnect vCenter
Disconnect-VIServer -Server $vCenterServer -Confirm:$false -Force:$true

#Accept Puppet Certs
sleep -Seconds 60
New-SSHSession -ComputerName $puppetmaster -Credential $ssh_cred
Invoke-SSHCommand -SessionId 0 -Command "sudo puppet cert sign --all"
Get-SSHSession | Remove-SSHSession
sleep -Seconds 20

#Run Puppet Agent on servers
foreach ($server in $servers){
    New-PSSession -ComputerName $server.Name -Credential $credentials
    Write-Verbose "Executing Puppet Run on $($server.Name)" -Verbose
    (Get-Date -Format ("[yyyy-MM-dd HH:mm:ss] ")) + ":Info: Invoking Puppet Agent on $($server.name)" | out-file $logfilename -Append
    Invoke-Command -ComputerName $server.Name -ScriptBlock {"C:\Program Files\Puppet Labs\Puppet\bin\puppet.bat agent"} -Credential $credentials
    #Remove Session after completed
    Write-Verbose "Removing session on $($server.Name)" -Verbose
    Remove-PSSession -ComputerName $server.Name
}

sleep -Seconds 60

#Run Puppet Agent on servers 2nd time
foreach ($server in $servers){
    New-PSSession -ComputerName $server.Name -Credential $credentials
    Write-Verbose "Executing Puppet Run on $($server.Name)" -Verbose
    (Get-Date -Format ("[yyyy-MM-dd HH:mm:ss] ")) + ":Info: Invoking Puppet Agent on $($server.name)" | out-file $logfilename -Append
    Invoke-Command -ComputerName $server.Name -ScriptBlock {"C:\Program Files\Puppet Labs\Puppet\bin\puppet.bat agent"} -Credential $credentials
    #Remove Session after completed
    Write-Verbose "Removing session on $($server.Name)" -Verbose
    Remove-PSSession -ComputerName $server.Name
}