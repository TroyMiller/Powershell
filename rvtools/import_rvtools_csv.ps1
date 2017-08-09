#Import RVTools to SQL using CSV files

$sqlserver = 'troy-sql'
$database = 'rvtools'
$sqluser = 'rvtools'
$sqlpassword = 'password'

Function ExportWSToCSV ($excelFile, $csvLoc)
{
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

function Import-vInfo($sqlserver, $database, $sqluser, $sqlpassword)
{

    
    $auth=@{UserName=$sqluser;Password=$sqlpassword}
    $sql_instance_name = $sqlserver 
    $db_name = $database
    
    $impcsv = (get-childitem C:\CSVFiles\*vinfo*.csv).FullName
    $data = import-csv $impcsv 
    $count = 1 
    
    foreach($i in $data){ 
        $scandate = $date
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
    
    $query = "INSERT INTO vInfo (scandate, customer, vm, powerstate, template, dns_name, poweron, cpus, memory, nics, disks, network_1, resource_pool, provisioned_MB, in_use_mb, unshared_mb, vm_path, annotation, datacenter, cluster, host, os_config, os_tools, vm_id, vm_uuid, vi_sdk_server_type, vi_sdk_server, vi_sdk_uuid) 
                VALUES ('$scandate','$customer','$vm','$powerstate','$template','$dns_name','$poweron','$cpus','$memory','$nics','$disks','$network_1','$resource_pool','$provisioned_MB','$in_use_mb','$unshared_mb','$vm_path','$annotation','$datacenter','$cluster','$vmhost','$os_config','$os_tools','$vm_id','$vm_uuid','$vi_sdk_server_type','$vi_sdk_server','$vi_sdk_uuid')" 
    
    $impcsv = invoke-sqlcmd -Database $db_name -Query $query  -serverinstance $sql_instance_name -verbose @auth
    
    write-host "vHost Processing row ..........$count" -foregroundcolor green 
    
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
        $scandate = $date
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
        
    
    $query = "INSERT INTO vDisk (scandate, customer, vm, powerstate, template, diskid, capacity_mb, israw, disk_mode, thin, eagerly_scrub, controller, unit_num, disk_path) 
                VALUES ('$scandate','$customer','$vm','$powerstate','$template', '$disk', '$capacity_mb', '$raw', '$disk_mode', '$thin', '$eagerly_scrub', '$controller', '$unit_num', '$disk_path')" 
    
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
        $scandate = $date
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
        
        
    
    $query = "INSERT INTO vPartition (scandate, customer, vm, diskid, template, capacity_mb, consumed_mb, free_mb, vm_id, vm_uuid ) 
                VALUES ('$scandate','$customer','$vm','$disk','$template','$capacity_mb','$consumed_mb','$free_mb','$vm_id','$vm_uuid')" 
    
    $impcsv = invoke-sqlcmd -Database $db_name -Query $query  -serverinstance $sql_instance_name -verbose @auth
    
    write-host "vPartition Processing row ..........$count" -foregroundcolor green 
    
    $count  = $count + 1 
    
    } 
}

$excelpath = Get-FileName "c:\"

#Prompt for Customer Name
$customer = Read-Host "Enter Customer Name"


ExportWSToCSV $excelpath -csvLoc "C:\CSVFiles\"

#Set date based on file creation
$filedate = (Get-item $excelpath).LastWriteTime
$date = $filedate.ToString("MM/dd/yyyy")


Import-vInfo $sqlserver $database $sqluser $sqlpassword
Import-vDisk $sqlserver $database $sqluser $sqlpassword
Import-vPartition $sqlserver $database $sqluser $sqlpassword

#Remove CSV Files
Remove-item C:\CSVFiles\*.csv -Confirm:$false