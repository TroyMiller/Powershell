$sqlserver = 'rvtools'
$database = 'rvtools'
$sqluser = 'rvtools'
$sqlpassword = 'rvtools'

function Get-FileName($initialDirectory)
{
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null
    
    $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $OpenFileDialog.initialDirectory = $initialDirectory
    $OpenFileDialog.ShowDialog() | Out-Null
    $OpenFileDialog.filename
}

function Import-Customers($sqlserver, $database, $sqluser, $sqlpassword, $filepath)
{

    
    $auth=@{UserName=$sqluser;Password=$sqlpassword}
    $sql_instance_name = $sqlserver 
    $db_name = $database
    
    $impcsv = (get-childitem $filepath).FullName
    $data = import-csv $impcsv 
    $count = 1 
    
    foreach($i in $data){ 
        $Lead = $i.lead
        $Company_Name = $i."Company Name".replace("'","")
        $Territory = $i.territory
        $CusType = $i.type
        $CusStatus = $i.status
        $CusSite = $i.Site
        $AddressLine1 = $i."Address Line 1".replace("'","")
        $City = $i.City
        $CusState = $i.State
       
    
    $query = "INSERT INTO Customers (Lead, Company_Name, Territory, CusType, CusStatus, CusSite, AddressLine1, City, CusState) 
                VALUES ('$Lead','$Company_Name','$Territory','$CusType','$CusStatus','$CusSite','$AddressLine1','$City','$CusState')" 
    
    $impcsv = invoke-sqlcmd -Database $db_name -Query $query  -serverinstance $sql_instance_name -verbose @auth
    
    write-host "Customer Processing row ..........$count" -foregroundcolor green 
    
    $count  = $count + 1 
    
    } 
}

$excelpath = Get-FileName "c:\"
Import-Customers $sqlserver $database $sqluser $sqlpassword $excelpath