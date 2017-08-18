#Import RVTools to SQL using CSV files
$sqlserver = 'rvtools'
$database = 'rvtools'
$sqluser = 'rvtools'
$sqlpassword = 'rvtools'


$snapin = Get-Module SQLServer
if ($snapin -eq $null) {
	Install-Module sqlserver
	if ($error.Count -eq 0) {
		Write-Host $logfilename "SQL Server Snap-in was successfully enabled." -ForegroundColor Green
	}
	else{
		Write-Host "Could not enable SQLServer Snap-in, exiting script" -ForegroundColor Red
		Exit
	}
}

Function Show-MsgBox ($Text,$Title="",[Windows.Forms.MessageBoxButtons]$Button = "OK",[Windows.Forms.MessageBoxIcon]$Icon="Information")
{
[Windows.Forms.MessageBox]::Show("$Text", "$Title", [Windows.Forms.MessageBoxButtons]::$Button, $Icon) | ?{(!($_ -eq "OK"))}
}

Function ExportWSToCSV ($excelFile, $csvLoc)
{
    If(!(test-path $csvLoc))
    {
        New-Item -ItemType Directory -Force -Path $csvLoc
    }

    $E = New-Object -ComObject Excel.Application
    $E.Visible = $false
    $E.DisplayAlerts = $false
    $wb = $E.Workbooks.Open($excelFile)
    foreach ($ws in $wb.Worksheets)
    {
        $n = "temp_" + $ws.Name
        $ws.SaveAs($csvLoc + $n + ".csv", 6)
    }
    $E.Workbooks.Close()
    $E.Quit()
    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($E)
    Remove-Variable E
}


function Get-FileName($initialDirectory)
{
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null
    
    $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $OpenFileDialog.initialDirectory = $initialDirectory
    $OpenFileDialog.ShowDialog() | Out-Null
    $OpenFileDialog.filename
}


function Get-CustomerList($sqlserver, $database, $sqluser, $sqlpassword)
{
    $auth=@{UserName=$sqluser;Password=$sqlpassword}
    $sql_instance_name = $sqlserver 
    $db_name = $database

    $query = "SELECT ID,Company_Name,CusSite FROM Customers"

    $results = invoke-sqlcmd -Database $db_name -Query $query  -serverinstance $sql_instance_name -verbose @auth

    return $results
}


function Set-ScanID($sqlserver, $database, $sqluser, $sqlpassword, $Customer_ID, $scandate)
{   
    $auth=@{UserName=$sqluser;Password=$sqlpassword}
    $sql_instance_name = $sqlserver 
    $db_name = $database
    $scandate = [datetime]$scandate

    $query = "SELECT ID,CUstomer_ID,ScanDate FROM SCAN_ID where Customer_ID = '$customer_ID' and ScanDate = '$scandate'"

    $results = invoke-sqlcmd -Database $db_name -Query $query  -serverinstance $sql_instance_name -verbose @auth
    if ($results) 
    {
        Write-Host "Possible Duplicate Scan Detected" -ForegroundColor Red
        If((Show-MsgBox -Title 'Possible Duplicate Scan Detected' -Text 'Would you like to continue with the Import process?' -Button YesNo -Icon Warning) -eq 'No'){Exit}
        $query = "INSERT INTO Scan_ID (Customer_ID, ScanDate) VALUES ('$Customer_ID','$scandate')"
        $create_scanid = invoke-sqlcmd -Database $db_name -Query $query  -serverinstance $sql_instance_name -verbose @auth
        Write-Host "Creating new Scan_ID" -ForegroundColor Green
    }
    Else
    {
        $query = "INSERT INTO Scan_ID (Customer_ID, ScanDate) VALUES ('$Customer_ID','$scandate')"
        $create_scanid = invoke-sqlcmd -Database $db_name -Query $query  -serverinstance $sql_instance_name -verbose @auth
        Write-Host "Creating new Scan_ID" -ForegroundColor Green
    }
    $query = "SELECT TOP 1 ID FROM SCAN_ID where Customer_ID = '$customer_ID' and ScanDate = '$scandate' ORDER BY ID DESC"
    $results = invoke-sqlcmd -Database $db_name -Query $query  -serverinstance $sql_instance_name -verbose @auth
    Return $results
}


function Import-vInfo($sqlserver, $database, $sqluser, $sqlpassword)
{

    
    $auth=@{UserName=$sqluser;Password=$sqlpassword}
    $sql_instance_name = $sqlserver 
    $db_name = $database
    
    $impcsv = (get-childitem C:\CSVFiles\*vinfo*.csv).FullName
    $data = import-csv $impcsv 
    $count = 1 
    
    foreach($i in $data){ 
        $scan_id = $scan_id
        $customer = $customer
        $vm = $i.vm
        $powerstate = $i.powerstate
        $template = $i.template
        $dns_name = $i."dns name"
        $poweron = $i.poweron
        $cpus = $i.cpus
        $memory = $i.memroy
        $nics = $i.nics
        $disks = $i.disks
        $network_1 = $i."network #1"
        $resource_pool = $i."resource pool"
        $provisioned_MB = $i."provisioned mb".replace(",","")
        $in_use_mb = $i."in use mb".replace(",","")
        $unshared_mb = $i."unshared mb".replace(",","")
        $vm_path = $i.path
        $annotation = $i.annotation.replace("'","")
        If ($annotation.length -ge 255)
        {    
            $annotation = $annotation.Substring(0,255)
        }
        $datacenter = $i.datacenter
        $cluster = $i.cluster
        $vmhost = $i.host
        $os_config = $i."OS according to the configuration file"
        $os_tools = $i."OS according to the VMware Tools"
        $vm_id = $i."vm id"
        $vm_uuid = $i."vm uuid"
        $vi_sdk_server_type = $i."vi sdk server type"
        $vi_sdk_server = $i."vi sdk server"
        $vi_sdk_uuid = $i."vi sdk uuid"
    
    $query = "INSERT INTO vInfo (scan_id, customer, vm, powerstate, template, dns_name, poweron, cpus, memory, nics, disks, network_1, resource_pool, provisioned_MB, in_use_mb, unshared_mb, vm_path, annotation, datacenter, cluster, host, os_config, os_tools, vm_id, vm_uuid, vi_sdk_server_type, vi_sdk_server, vi_sdk_uuid) 
                VALUES ('$scan_id','$customer','$vm','$powerstate','$template','$dns_name','$poweron','$cpus','$memory','$nics','$disks','$network_1','$resource_pool','$provisioned_MB','$in_use_mb','$unshared_mb','$vm_path','$annotation','$datacenter','$cluster','$vmhost','$os_config','$os_tools','$vm_id','$vm_uuid','$vi_sdk_server_type','$vi_sdk_server','$vi_sdk_uuid')" 
    
    $impcsv = invoke-sqlcmd -Database $db_name -Query $query  -serverinstance $sql_instance_name -verbose @auth
    
    write-host "vInfo Processing row ..........$count" -foregroundcolor green 
    
    $count  = $count + 1 
    
    } 
}



function Import-vDisk($sqlserver, $database, $sqluser, $sqlpassword)
{

    
    $auth=@{UserName=$sqluser;Password=$sqlpassword}
    $sql_instance_name = $sqlserver 
    $db_name = $database
    
    $impcsv = (get-childitem C:\CSVFiles\*vdisk*.csv).FullName
    $data = import-csv $impcsv 
    $count = 1 
    
    foreach($i in $data){ 
        $scan_id = $scan_id
        $customer = $customer
        $vm = $i.vm
        $powerstate = $i.powerstate
        $template = $i.template
        $disk = $i.disk
        $capacity_mb = $i."Capacity MB".replace(",","")
        $raw = $i.raw
        $disk_mode = $i."disk mode"
        $thin = $i.thin
        $eagerly_scrub = $i."Eagerly Scrub"
        $controller = $i.controller
        $unit_num = $i."Unit #"
        $disk_path = $i.path
        
    
    $query = "INSERT INTO vDisk (scan_id, customer, vm, powerstate, template, diskid, capacity_mb, israw, disk_mode, thin, eagerly_scrub, controller, unit_num, disk_path) 
                VALUES ('$scan_id','$customer','$vm','$powerstate','$template', '$disk', '$capacity_mb', '$raw', '$disk_mode', '$thin', '$eagerly_scrub', '$controller', '$unit_num', '$disk_path')" 
    
    $impcsv = invoke-sqlcmd -Database $db_name -Query $query  -serverinstance $sql_instance_name -verbose @auth
    
    write-host "vDisk Processing row ..........$count" -foregroundcolor green 
    
    $count  = $count + 1 
    
    } 
}



function Import-vPartition($sqlserver, $database, $sqluser, $sqlpassword)
{

    
    $auth=@{UserName=$sqluser;Password=$sqlpassword}
    $sql_instance_name = $sqlserver 
    $db_name = $database
    
    $impcsv = (get-childitem C:\CSVFiles\*vpartition*.csv).FullName
    $data = import-csv $impcsv 
    $count = 1 
    
    foreach($i in $data){ 
        $scan_id = $scan_id
        $customer = $customer
        $vm = $i.vm
        $template = $i.template
        $disk = $i.disk
        $capacity_mb = $i."Capacity MB".replace(",","")
        $free_mb = $i."Free MB".replace(",","")
        If ($i."Consumed MB" -ne $null)
        {
            $consumed_mb = $i."Consumed MB".replace(",","")
        }
        Else
        {
            $consumed_mb = $capacity_mb - $free_mb
        }
        $vm_id = $i."vm id"
        $vm_uuid = $i."vm uuid"
        
        
    
    $query = "INSERT INTO vPartition (scan_id, customer, vm, diskid, template, capacity_mb, consumed_mb, free_mb, vm_id, vm_uuid ) 
                VALUES ('$scan_id','$customer','$vm','$disk','$template','$capacity_mb','$consumed_mb','$free_mb','$vm_id','$vm_uuid')" 
    
    $impcsv = invoke-sqlcmd -Database $db_name -Query $query  -serverinstance $sql_instance_name -verbose @auth
    
    write-host "vPartition Processing row ..........$count" -foregroundcolor green 
    
    $count  = $count + 1 
    
    } 
}



function Import-vHealth($sqlserver, $database, $sqluser, $sqlpassword)
{

    
    $auth=@{UserName=$sqluser;Password=$sqlpassword}
    $sql_instance_name = $sqlserver 
    $db_name = $database
    
    $impcsv = (get-childitem C:\CSVFiles\*vhealth*.csv).FullName
    $data = import-csv $impcsv 
    $count = 1 
    
    foreach($i in $data){ 
        $scan_id = $scan_id
        $customer = $customer
        $vmName = $i.name
        $vmMessage = $i.Message
        $vi_sdk_server = $i."vi sdk server"
        $vi_sdk_uuid = $i."vi sdk uuid"
        
        
    
    $query = "INSERT INTO vHealth (scan_id, customer, vmName, vmMessage, vi_sdk_server, vi_sdk_uuid) 
                VALUES ('$scan_id','$customer','$vmName','$vmMessage','$vi_sdk_server','$vi_sdk_uuid')" 
    
    $impcsv = invoke-sqlcmd -Database $db_name -Query $query  -serverinstance $sql_instance_name -verbose @auth
    
    write-host "vHealth Processing row ..........$count" -foregroundcolor green 
    
    $count  = $count + 1 
    
    } 
}



function Import-vCluster($sqlserver, $database, $sqluser, $sqlpassword)
{

    
    $auth=@{UserName=$sqluser;Password=$sqlpassword}
    $sql_instance_name = $sqlserver 
    $db_name = $database
    
    $impcsv = (get-childitem C:\CSVFiles\*vcluster*.csv).FullName
    $data = import-csv $impcsv 
    $count = 1 
    
    foreach($i in $data){ 
        $scan_id = $scan_id
        $customer = $customer
        $ClusterName = $i.name
        $NumHosts = $i.NumHosts
        $numEffectiveHosts = $i.NumEffectiveHosts
        $TotalCpu = $i.TotalCPU.replace(",","")
        $NumCpuCores = $i.NumCPUCores
        $NumCpuThreads = $i.NumCPUThreads
        $Effective_Cpu = $i."Effective CPU".replace(",","")
        $TotalMemory = $i.TotalMemory.replace(",","")
        $Effective_Memory = $i."Effective Memory".replace(",","")
        $HA = $i."HA Enabled"
        $Failover = $i."Failover Level"
        $AdmissionControlEnabled = $i.AdmissionControlEnabled
        $Host_monitoring = $i."Host Monitoring"
        $HB_Datastore_Candidate_Policy = $i."HB Datastore Candidate Policy"
        $VM_Monitoring = $i."VM Monitoring"
        $DRS = $i."DRS Enabled"
        $DRS_default_VM_behavior = $i."DRS Default VM Behavior"
        $DRS_vmotion_rate = $i."DRS vmotion rate"
        $vi_sdk_server = $i."vi sdk server"
        $vi_sdk_uuid = $i."vi sdk uuid"
        
        
    
    $query = "INSERT INTO vCluster (scan_id, customer, ClusterName, NumHosts, numEffectiveHosts, TotalCpu, NumCpuCores, NumCpuThreads, Effective_Cpu, TotalMemory, Effective_Memory, HA_enabled, Failover_Level, AdmissionControlEnabled, Host_monitoring, HB_Datastore_Candidate_Policy, VM_Monitoring, DRS_enabled, DRS_default_VM_behavior, DRS_vmotion_rate, VI_SDK_Server, VI_SDK_UUID ) 
                VALUES ('$scan_id','$customer','$ClusterName','$NumHosts','$numEffectiveHosts','$TotalCpu','$NumCpuCores','$NumCpuThreads','$Effective_Cpu','$TotalMemory','$Effective_Memory','$HA','$Failover','$AdmissionControlEnabled','$Host_monitoring','$HB_Datastore_Candidate_Policy','$VM_Monitoring','$DRS','$DRS_default_VM_behavior','$DRS_vmotion_rate','$vi_sdk_server','$vi_sdk_uuid')" 
    
    $impcsv = invoke-sqlcmd -Database $db_name -Query $query  -serverinstance $sql_instance_name -verbose @auth
    
    write-host "vCluster Processing row ..........$count" -foregroundcolor green 
    
    $count  = $count + 1 
    
    } 
}



function Import-vHost($sqlserver, $database, $sqluser, $sqlpassword)
{

    
    $auth=@{UserName=$sqluser;Password=$sqlpassword}
    $sql_instance_name = $sqlserver 
    $db_name = $database
    
    $impcsv = (get-childitem C:\CSVFiles\*vhost*.csv).FullName
    $data = import-csv $impcsv 
    $count = 1 
    
    foreach($i in $data){ 
        $scan_id = $scan_id
        $customer = $customer
        $HostName = $i.host
        $Datacenter = $i.datacenter
        $CPU_Model = $i."cpu model"
        $Speed = $i.speed.replace(",","")
        $HT_Available = $i."HT Available"
        $HT_Active = $i."HT Active"
        $num_CPU = $i."# CPU"
        $Cores_per_CPU = $i."Cores per CPU"
        $num_Cores = $i."# Cores"
        $CPU_usage = $i."CPU usage%"
        $num_Memory = $i."# Memory".replace(",","")
        $Memory_usage = $i."Memory usage %"
        $num_NICs = $i."# NICs"
        $num_HBAs = $i."# HBAs"
        $num_VMs = $i."# VMs"
        $VMs_per_Core = $i."VMs per Core"
        $num_vCPUs = $i."# vCPUs"
        $vCPUs_per_Core = $i."vCPUs per Core"
        $vRAM = $i.vRAM.replace(",","")
        $VM_Used_memory = $i."VM Used memory".replace(",","")
        $VMotion_support = $i."VMotion support"
        $Storage_VMotion_support = $i."Storage VMotion support"
        $Current_EVC = $i."Current EVC"
        $Max_EVC = $i."Max EVC"
        $ESX_Version = $i."ESX Version"
        $Domain = $i.Domain	
        $DNS_Search_Order = $i."DNS Search Order"
        $NTP_Servers = $i."NTP Server(s)"
        $Vendor = $i.Vendor
        $Model = $i.Model
        $Service_tag = $i."Service tag"
        $OEM_specific_string = $i."OEM specific string"
        $BIOS_Version = $i."BIOS Version"
        $BIOS_Date = $i."BIOS Date"
        $Object_ID = $i."Object ID"
        $VI_SDK_Server = $i."vi sdk server"
        $VI_SDK_UUID = $i."vi sdk uuid"
       
    
    $query = "INSERT INTO vHost (scan_id, customer, Hostname, Datacenter, CPU_Model, Speed, HT_Available, HT_Active, num_CPU, Cores_per_CPU, num_Cores, CPU_usage, num_Memory, Memory_usage, num_NICs, num_HBAs, num_VMs, VMs_per_Core, num_vCPUs, vCPUs_per_Core, vRAM, VM_Used_memory, VMotion_support, Storage_VMotion_support, Current_EVC, Max_EVC, ESX_Version, Domain, DNS_Search_Order, NTP_Servers, Vendor, Model, Service_tag, OEM_specific_string, BIOS_Version, BIOS_Date, Object_ID, VI_SDK_Server, VI_SDK_UUID) 
                VALUES ('$scan_id','$customer','$Hostname','$Datacenter','$CPU_Model','$Speed','$HT_Available','$HT_Active','$num_CPU','$Cores_per_CPU','$num_Cores','$CPU_usage','$num_Memory','$Memory_usage','$num_NICs','$num_HBAs','$num_VMs','$VMs_per_Core','$num_vCPUs','$vCPUs_per_Core','$vRAM','$VM_Used_memory','$VMotion_support','$Storage_VMotion_support','$Current_EVC','$Max_EVC','$ESX_Version','$Domain','$DNS_Search_Order','$NTP_Servers','$Vendor','$Model','$Service_tag','$OEM_specific_string','$BIOS_Version','$BIOS_Date','$Object_ID','$VI_SDK_Server','$VI_SDK_UUID')" 
    
    $impcsv = invoke-sqlcmd -Database $db_name -Query $query  -serverinstance $sql_instance_name -verbose @auth
    
    write-host "vHost Processing row ..........$count" -foregroundcolor green 
    
    $count  = $count + 1 
    
    } 
}


function Import-vDatastore($sqlserver, $database, $sqluser, $sqlpassword)
{

    
    $auth=@{UserName=$sqluser;Password=$sqlpassword}
    $sql_instance_name = $sqlserver 
    $db_name = $database
    
    $impcsv = (get-childitem C:\CSVFiles\*vdatastore*.csv).FullName
    $data = import-csv $impcsv 
    $count = 1 
    
    foreach($i in $data){ 
        $scan_id = $scan_id
        $customer = $customer
        $Name = $i.Name
        $Address = $i.Address
        $Accessible = $i.Accessible
        $Type = $i.Type
        $num_VMs = $i."# VMs"
        $Capacity_MB = $i."Capacity MB".replace(",","")
        $Provisioned_MB = $i."Provisioned MB".replace(",","")
        $In_Use_MB = $i."In Use MB".replace(",","")
        $Free_MB = $i."Free MB".replace(",","")
        $FreePercent = $i."Free %"
        $SIOC_enabled = $i."SIOC enabled"
        $SIOC_Threshold = $i."SIOC Threshold"
        $num_Hosts = $i."# Hosts"
        $Hosts = $i.Hosts
        $Block_size = $i."Block size"
        $Max_Blocks = $i."Max Blocks".replace(",","")
        $num_Extents = $i."# Extents"
        $Major_Version = $i."Major Version"
        $Version = $i.Version
        $VMFS_Upgradeable = $i."VMFS_Upgradeable"
        $MHA = $i.MHA
        $URL = $i.URL
        $VI_SDK_Server = $i."vi sdk server"
        $VI_SDK_UUID = $i."vi sdk uuid"
       
    
    $query = "INSERT INTO vDatastore (scan_id, customer, dsName, dsAddress, Accessible, dsType, num_VMs, Capacity_MB, Provisioned_MB, In_Use_MB, Free_MB, FreePercent, SIOC_enabled, SIOC_Threshold, num_Hosts, Hosts, Block_size, Max_Blocks, num_Extents, Major_Version, dsVersion, VMFS_Upgradeable, MHA, dsURL, VI_SDK_Server, VI_SDK_UUID) 
                VALUES ('$scan_id','$customer','$Name','$Address','$Accessible','$Type','$num_VMs','$Capacity_MB','$Provisioned_MB','$In_Use_MB','$Free_MB','$FreePercent','$SIOC_enabled','$SIOC_Threshold','$num_Hosts','$Hosts','$Block_size','$Max_Blocks','$num_Extents','$Major_Version','$Version','$VMFS_Upgradeable','$MHA','$URL','$VI_SDK_Server','$VI_SDK_UUID')" 
    
    $impcsv = invoke-sqlcmd -Database $db_name -Query $query  -serverinstance $sql_instance_name -verbose @auth
    
    write-host "vDatastore Processing row ..........$count" -foregroundcolor green 
    
    $count  = $count + 1 
    
    } 
}


function Import-vLicense($sqlserver, $database, $sqluser, $sqlpassword)
{

    
    $auth=@{UserName=$sqluser;Password=$sqlpassword}
    $sql_instance_name = $sqlserver 
    $db_name = $database
    
    $impcsv = (get-childitem C:\CSVFiles\*vlicense*.csv).FullName
    $data = import-csv $impcsv 
    $count = 1 
    
    foreach($i in $data){ 
        $scan_id = $scan_id
        $customer = $customer
        $LicenseName = $i.Name
        $LicenseKey	= $i.Key
        $Labels	= $i.Labels
        $Cost_Unit = $i."Cost Unit"
        $Total = $i.total	
        $Used = $i.Used
        $Expiration_Date = $i."Expiration Date"
        $Features = $i.features
        If ($Features.length -ge 1024)
        {    
            $Features = $Features.Substring(0,1024)
        }
        $VI_SDK_Server = $i."vi sdk server"
        $VI_SDK_UUID = $i."vi sdk uuid"
       
    
    $query = "INSERT INTO vLicense (scan_id, customer, LicenseName, LicenseKey, Labels, Cost_Unit, Total, Used, Expiration_Date, Features, VI_SDK_Server, VI_SDK_UUID) 
                VALUES ('$scan_id','$customer','$LicenseName','$LicenseKey','$Labels','$Cost_Unit','$Total','$Used','$Expiration_Date','$Features','$VI_SDK_Server','$VI_SDK_UUID')" 
    
    $impcsv = invoke-sqlcmd -Database $db_name -Query $query  -serverinstance $sql_instance_name -verbose @auth
    
    write-host "vLicense Processing row ..........$count" -foregroundcolor green 
    
    $count  = $count + 1 
    
    } 
}


function Import-vMemory($sqlserver, $database, $sqluser, $sqlpassword)
{

    
    $auth=@{UserName=$sqluser;Password=$sqlpassword}
    $sql_instance_name = $sqlserver 
    $db_name = $database
    
    $impcsv = (get-childitem C:\CSVFiles\*vmemory*.csv).FullName
    $data = import-csv $impcsv 
    $count = 1 
    
    foreach($i in $data){ 
        $scan_id = $scan_id
        $customer = $customer
        $VM	= $i.vm
        $Powerstate	= $i.Powerstate
        $Template = $i.Template
        $Size_MB = $i."Size MB".replace(",","")
        $Overhead = $i.Overhead.replace(",","")
        $Max = $i.Max.replace(",","")
        $Consumed = $i."Consumed".replace(",","")
        $Consumed_Overhead = $i."Consumed Overhead".replace(",","")
        $Private = $i.Private.replace(",","")
        $Shared	= $i.Shared.replace(",","")
        $Swapped 	= $i.Swapped.replace(",","")
        $Ballooned	= $i.Ballooned.replace(",","")
        $Active = $i.Active.replace(",","")
        $Entitlement = $i.Entitlement.replace(",","")
        $DRS_Entitlement = $i."DRS Entitlement".replace(",","")
        $Shares	= $i.Shares.replace(",","")
        $Reservation = $i.Reservation.replace(",","")
        $Limit	= $i.Limit.replace(",","")
        $Hot_Add = $i."Hot Add"
        $VM_ID	= $i."VM ID"
        $VM_UUID = $i."VM UUID"
        $VI_SDK_Server = $i."vi sdk server"
        $VI_SDK_UUID = $i."vi sdk uuid"
       
    
    $query = "INSERT INTO vMemory (scan_id, customer, VM, Powerstate, Template, Size_MB, Overhead, ramMax, Consumed, Consumed_Overhead, ramPrivate, Shared, Swapped, Ballooned, Active, Entitlement, DRS_Entitlement, Shares, Reservation, ramLimit, Hot_Add, VM_ID, VM_UUID, VI_SDK_Server, VI_SDK_UUID) 
                VALUES ('$scan_id','$customer','$VM','$Powerstate','$Template','$Size_MB','$Overhead','$Max','$Consumed','$Consumed_Overhead','$Private','$Shared','$Swapped','$Ballooned','$Active','$Entitlement','$DRS_Entitlement','$Shares','$Reservation','$Limit','$Hot_Add','$VM_ID','$VM_UUID','$VI_SDK_Server','$VI_SDK_UUID')" 
    
    $impcsv = invoke-sqlcmd -Database $db_name -Query $query  -serverinstance $sql_instance_name -verbose @auth
    
    write-host "vMemory Processing row ..........$count" -foregroundcolor green 
    
    $count  = $count + 1 
    
    } 
}

$excelpath = Get-FileName "c:\"

#Prompt for Customer Name
#$customer = Read-Host "Enter Customer Name"
$customer = Get-CustomerList $sqlserver $database $sqluser $sqlpassword | Out-GridView -PassThru -Title "Choose Customer Name for Import" 
$customername = $customer.Company_Name
$customer = $customer.ID




#Set date based on file creation
$filedate = (Get-item $excelpath).LastWriteTime
$date = $filedate.ToString("MM/dd/yyyy")
$date = Read-host -Prompt "RVTools Import date [$date]"
if ([string]::IsNullOrWhiteSpace($date))
    {
    $date=$filedate.ToString("MM/dd/yyyy")
    }

ExportWSToCSV $excelpath -csvLoc "C:\CSVFiles\"

$scan_id = Set-ScanID $sqlserver $database $sqluser $sqlpassword $customer $date
$scan_id = $scan_id.id
Import-vInfo $sqlserver $database $sqluser $sqlpassword
Import-vDisk $sqlserver $database $sqluser $sqlpassword
Import-vPartition $sqlserver $database $sqluser $sqlpassword
Import-vHealth $sqlserver $database $sqluser $sqlpassword
Import-vCluster $sqlserver $database $sqluser $sqlpassword
Import-vHost $sqlserver $database $sqluser $sqlpassword
Import-vDatastore $sqlserver $database $sqluser $sqlpassword
Import-vLicense $sqlserver $database $sqluser $sqlpassword
Import-vMemory $sqlserver $database $sqluser $sqlpassword

#Remove CSV Files
Remove-item C:\CSVFiles\*.csv -Confirm:$false

#Final Notice
Write-Verbose "Scan ($scan_id) - Successfully imported $excelpath from $date for $customername " -Verbose