
#Original can be found at https://github.com/DBArgenis/pure-storage/blob/master/Refresh-Dev-From-VMDK.ps1
<#
.SYNOPSIS
    
    Script automates database refresh from JM Scrub Environment (JMTSQL991, JMTSQL992, JMTSQL993, JMTSQL994)

.DESCRIPTION



.PARAMETER Environment

    Mandatory parameter indicating Environment to refresh to (Examples - QA00, QA01, DEV01, DEV02
   
.EXAMPLE

    pure_refresh.ps1 -Environment QA00
     
    
.EXAMPLE

    pure_refresh.ps1
    
    Script will interactively ask for mandatory vCenterServer parameter
 
#>


[CmdletBinding()]
Param(
   [Parameter(Mandatory=$True,Position=1)]
   [ValidateNotNullOrEmpty()]
   [string]$Environment
)

Import-Module VMware.VimAutomation.Core
Import-Module PureStoragePowerShellSDK

#Credentials used to invoke commands on servers
$admincreds = Get-Credential

#Variables
$ScriptRoot = Split-Path $MyInvocation.MyCommand.Path
$StartTime = Get-Date -Format "yyyyMMddHHmmss_"
$logdir = $ScriptRoot + "\PureRefreshLogs\"
$transcriptfilename = $logdir + $StartTime + "transcript-purerefresh.log"
$logfilename = $logdir + $StartTime + "purerefresh.log"
$SourceVMs = @('JMTSQL991', 'JMTSQL992', 'JMTSQL993', 'JMTSQL994')
#$Environment = 'QA00'
$DatabaseNames = 'TestDB'
$VIServerName = 'jmpvcr01.jewelersnt.local'
$SourceDatastoreName = 'PureM01_VM_SQL_SCRUB'
$ArrayName = 'PureM01.jewelersnt.local'
$SourceVolumeName = 'PureM01_VM_SQL_SCRUB'
$TargetVolumeName = "PureM01_VM_SQL_SCRUB_$Environment"
$HostGroupName = 'JMDEV01'
$TargetVMs = @()
[int]$SQL_servers = 4
$servers = @()
[int]$count = 1

Function Unmount-Datastore {
	[CmdletBinding()]
	Param (
		[Parameter(ValueFromPipeline=$true)]
		$Datastore
	)
	Process {
		if (-not $Datastore) {
			Write-Host "No Datastore defined as input"
			Exit
		}
		Foreach ($ds in $Datastore) {
			$hostviewDSDiskName = $ds.ExtensionData.Info.vmfs.extent[0].Diskname
			if ($ds.ExtensionData.Host) {
				$attachedHosts = $ds.ExtensionData.Host
				Foreach ($VMHost in $attachedHosts) {
					$hostview = Get-View $VMHost.Key
					$StorageSys = Get-View $HostView.ConfigManager.StorageSystem
					Write-and-Log "Unmounting VMFS Datastore $($DS.Name) from host $($hostview.Name)..."
					$StorageSys.UnmountVmfsVolume($DS.ExtensionData.Info.vmfs.uuid);
				}
			}
		}
	}
}


Function Write-and-Log ($Message)
{
    Write-Host (Get-Date -Format ("[yyyy-MM-dd HH:mm:ss] ")) "$message" -ForegroundColor Yellow
    (Get-Date -Format ("[yyyy-MM-dd HH:mm:ss] ")) + "$message" | out-file $logfilename -Append
}


#Setting $env to build server name
switch -Wildcard ($Environment) 
{ 
    "Q*" {$env = "t"}
    "D*" {$env = "d"} 
    "S*" {$env = "s"} 
    default {"No environment set"; exit;}
}

#Use $env to determine SQL env number 100 = Dev, 200 = Test, 500 = Stage, <100 = Prod
switch ($env) 
{ 
    "d" {$env_sql_num = "1"} 
    "t" {$env_sql_num = "2"} 
    "s" {$env_sql_num = "5"} 
    default {"No environment set"; exit;}
}

#Sets $env_num based on last character of $Environment
$env_num = $Environment.Substring($Environment.Length - 1,1)

#Number of SQL servers per environment
While ($count -le $SQL_servers)
{
    #Configures names for SQL servers
    $servers += "jm" + $env + "sql" + $env_sql_num + $env_num + $count
    $count++
}

Foreach ($server in $servers)
{
    $server_num = $server.Substring($server.Length - 1,1)
    switch ($server_num)
    {
        1 {$vmdkpath = '2008/2008.vmdk'}
        2 {$vmdkpath = '2008R2/2008R2.vmdk'}
        3 {$vmdkpath = '2012/2012.vmdk'}
        4 {$vmdkpath = 'DW12/DW12.vmdk'}
        default {"No server number";exit;}
    }

    switch ($server_num)
    {
        1 {$vmdiskserialnumber = '6000c29efc89c23aa680d0dc02d31cd8'}
        2 {$vmdiskserialnumber = '6000c29c357fcd03d14fc98941c362aa'}
        3 {$vmdiskserialnumber = '6000c293fd24515e0b97795d45d49c17'}
        4 {$vmdiskserialnumber = '6000c29da5732ab8325f030c29a4fb8c'}
        default {"No server number";exit;}
    }
    $TargetVM = New-Object PSObject
    $TargetVM | Add-Member -Name "VMName" -Value $server -MemberType NoteProperty
    $TargetVM | Add-Member -Name "VMDKPath" -value $vmdkpath -MemberType NoteProperty
    $TargetVM | Add-Member -Name "VMDiskSerialNumber" -value $VMDiskSerialNumber -MemberType NoteProperty
    $TargetVMs += $TargetVM

}


#test for log directory, create if needed
if ( -not (Test-Path $logdir)) {
			New-Item -type directory -path $logdir | out-null
}



# Connect to vSphere vCenter server
#Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false  # I'm ignoring certificate errors - this you probably won't want to ignore.
Write-and-Log "Connecting to vCenter: $VIServerName"
$VIServer = Connect-VIServer -Server $VIServerName -Credential $admincreds

Foreach($TargetVM in $TargetVMs) 
{
    # Create a Powershell session against the target VM
    $TargetVMSession = New-PSSession -ComputerName $TargetVM.VMName -Credential $admincreds
    #Write-Host "Importing SQLPS module on target VM..." -ForegroundColor Red
    #Import-Module SQLPS -PSSession $TargetVMSession -DisableNameChecking
    $VMDiskSerialNumber = $TargetVM.VMDiskSerialNumber
    $VMHostname = (Get-VM $($TargetVM.VMName)).VMHost


    # Offline the target database
    $ScriptBlock = [ScriptBlock]::Create("Invoke-Sqlcmd -ServerInstance . -Database master -Query `"ALTER DATABASE $DatabaseName SET OFFLINE WITH ROLLBACK IMMEDIATE`"")
    Write-and-Log ":Info: Offline database on $($TargetVM.VMName)"
    #Invoke-Command -Session $TargetVMSession -ScriptBlock $ScriptBlock


    # Offline the guest target volume
    Write-and-Log ":Info: Offline disk $VMDiskSerialNumber on $($TargetVM.VMName)"
    #Invoke-Command -Session $TargetVMSession -ScriptBlock { Get-Disk | ? { $_.Number -eq $TargetVMDiskNumber } | Set-Disk -IsOffline $True }
    Invoke-Command -Session $TargetVMSession -ScriptBlock {param($VMDiskSerialNumber) Get-Disk | ? { $_.Number -eq $TargetVM.VMDiskSerialNumber } | Set-Disk -IsOffline $True } -argumentlist $VMDiskSerialNumber




    # Remove the VMDK from the VM
    $VM = Get-VM -Server $VIServer -Name $TargetVM.VMName
    $harddisk = Get-HardDisk -VM $VM | ? { $_.FileName -match $TargetVM.VMDKPath }
    
    if ($harddisk -ne $null)
    {
        Write-and-Log ":Info: Removing disk on $($TargetVM.VMName)" 
        Remove-HardDisk -HardDisk $harddisk -Confirm:$false
    }
    else
    {
        Write-and-Log ":Info: No disk found on $($TargetVM.VMName)" 
    }

    # Guest hard disk removed, now remove the stale datastore
    #$datastore = $harddisk.filename.Substring(1, ($harddisk.filename.LastIndexOf(']') - 1))

}
Get-PSSession | Disconnect-PSSession | Remove-Pssession | Out-Null

$esxihosts = get-vmhost -location $HostGroupName -state "connected"
foreach($esxihost in $esxihosts)
{
    Write-and-Log ":Info: Refreshing Storage on $esxihost" 
    Get-VMHostStorage -Refresh -VMHost $esxihost | out-null
} 


Try 
{
    Write-and-Log ":Info: Removing datastore $TargetVolumeName" 
    Get-Datastore $TargetVolumeName | Unmount-Datastore
    Get-Datastore $TargetVolumeName | Remove-Datastore -VMHost $VMhostname -Confirm:$false -ErrorAction Stop | out-null
}
Catch
{
    Write-and-Log ":Error: Failed to remove datastore: $TargetVolumeName"
    Break

}
Foreach($SourceVM in $SourceVMs)
{
    # Let's do a quick CHECKPOINT on the source database to minimize crash recovery time upon startup on target - optional of course
    $SourceVMSession = New-PSSession -ComputerName $SourceVM -Credential $admincreds
    $ScriptBlock = [ScriptBlock]::Create("Invoke-Sqlcmd -ServerInstance . -Database $DatabaseName -Query `"CHECKPOINT`"")
    Write-and-Log ":Info: Creating CheckPoint on $($TargetVM.VMName) for database: $DatabaseName" 
    #Invoke-Command -Session $SourceVMSession -ScriptBlock $ScriptBlock
}


# Connect to the array, authenticate. Remember disclaimer at the top!
#Write-Host "Connecting to Pure FlashArray..." -ForegroundColor Red
Write-and-Log ":Info: Connecting to $ArrayName"
$FlashArray = New-PfaArray –EndPoint $ArrayName -Credential $admincreds -IgnoreCertificateError


# Perform the volume overwrite (no intermediate snapshot needed!)
#Write-Host "Performing datastore array volume clone..." -ForegroundColor Red
Write-and-Log ":Info: Cloning $SourceVolumeName to $TargetVolumeName on $ArrayName" 
New-PfaVolume -Array $FlashArray -VolumeName $TargetVolumeName -Source $SourceVolumeName -Overwrite | out-null


#Map LUN to Hosts if it isn't currently mapped
Write-and-Log ":Info: Mapping Volumes to $HostGroupName" 
$PFAVolumeConnection = Get-PfaHostGroupVolumeConnections -Array $FlashArray -HostGroupName $HostGroupName | where-object {$_.vol -eq $TargetVolumeName}
If ($PFAVolumeConnection -eq $null){    
    New-PfaHostGroupVolumeConnection -Array $FlashArray -VolumeName $TargetVolumeName -HostGroupName $HostGroupName | out-null
}


# Now let's tell the ESX host to rescan storage
$VMHost = Get-VMHost $VMHostname 
#Write-Host "Rescanning storage on VM host..." -ForegroundColor Red
Write-and-Log ":Info: Scanning for added disk on $VMHost" 
Get-VMHostStorage -RescanAllHba -RescanVmfs -VMHost $VMHost | out-null
$esxcli = Get-EsxCli -VMHost $VMHost


# If debug needed, use: $snapInfo = $esxcli.storage.vmfs.snapshot.list()
# Do a resignature of the datastore
Write-and-Log ":Info: Performing resignature of $SourceDatastoreName" 
$esxcli.storage.vmfs.snapshot.resignature($SourceDatastoreName)


# Find the assigned datastore name
Write-and-Log ":Info: waiting for datastore: $SourceDatastoreName to come online"
$datastore = (Get-Datastore | ? { $_.name -match 'snap' -and $_.name -match $SourceDatastoreName })
while ($datastore -eq $null) { # We may have to wait a little bit before the datastore is fully operational
    $datastore = (Get-Datastore | ? { $_.name -match 'snap' -and $_.name -match $SourceDatastoreName })
    Start-Sleep -Seconds 5
}
#Rename Datastore to reflect server using
write-and-log ":Info: Renaming $datastore to $TargetVolumeName"
Set-Datastore -Datastore $datastore -name $TargetVolumeName | out-null

$esxihosts = get-vmhost -location $HostGroupName -state "connected"
foreach($esxihost in $esxihosts)
{
    Get-VMHostStorage -RescanAllHba -RescanVmfs -VMHost $esxihost | out-null
}   
sleep -Seconds 15
Foreach($TargetVM in $TargetVMs)
{
    $TargetVMSession = New-PSSession -ComputerName $TargetVM.VMName -Credential $admincreds
    # Attach the VMDK to the target VM
    Write-and-Log "Attaching VMDK to $($TargetVM.VMName)"
    Get-VM $TargetVM.VMName | New-HardDisk -DiskPath "[$TargetVolumeName] $($TargetVM.VMDKPath)" -Confirm:$false | out-null
    $VMDiskSerialNumber = $TargetVM.VMDiskSerialNumber

    # Online the guest target volume
    Write-and-Log "Configuring disk (online) on $($TargetVM.VMName) for SN: $VMDiskSerialNumber"
    #Invoke-Command -Session $TargetVMSession -ScriptBlock { Get-Disk | ? { $_.Number -eq $TargetVMDiskNumber } | Set-Disk -IsOffline $False }
    Invoke-Command -Session $TargetVMSession -ScriptBlock {param($VMDiskSerialNumber) Get-Disk | ? { $_.SerialNumber -eq $VMDiskSerialNumber } | Set-Disk -IsOffline $false } -argumentlist $VMDiskSerialNumber
 


    # Volume might be read-only, let's force read/write. These things happen sometimes...
    Write-and-Log "Configuring disk (read/write) on $($TargetVM.VMName) for SN: $VMDiskSerialNumber"
    Invoke-Command -Session $TargetVMSession -ScriptBlock {param($VMDiskSerialNumber) Get-Disk | ? { $_.SerialNumber -eq $VMDiskSerialNumber } | Set-Disk -IsReadOnly $False } -argumentlist $VMDiskSerialNumber

    # Online the database
    $ScriptBlock = [ScriptBlock]::Create("Invoke-Sqlcmd -ServerInstance . -Database master -Query `"ALTER DATABASE $DatabaseName SET ONLINE WITH ROLLBACK IMMEDIATE`"")
    Write-and-Log "Enabling $database on $($TargetVM.VMName)"
    #Invoke-Command -Session $TargetVMSession -ScriptBlock $ScriptBlock



}

Get-PSSession | Disconnect-PSSession | Remove-Pssession | Out-Null
Disconnect-PfaArray -Array $FlashArray
Disconnect-VIServer -server $VIServerName -Confirm:$false