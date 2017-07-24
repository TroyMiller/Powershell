[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | Out-Null
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO.SqlDataType') | Out-Null

function Get-FileName($initialDirectory)
{
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null
    
    $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $OpenFileDialog.initialDirectory = $initialDirectory
    $OpenFileDialog.ShowDialog() | Out-Null
    $OpenFileDialog.filename
}

#create object to open Excel workbook
$filepath = Get-FileName "c:\temp"
$Excel = New-Object -ComObject Excel.Application
$Workbook = $Excel.Workbooks.Open($filepath)

#some variables
$serverName = "sql\sqlexpress";
$databaseName = "rvtools" ;
$uid = "rvtools";
$pwd = "password";
 
$mySrvConn = new-object Microsoft.SqlServer.Management.Common.ServerConnection
$mySrvConn.ServerInstance=$servername
$mySrvConn.LoginSecure = $false
$mySrvConn.Login = "rvtools"
$mySrvConn.Password = "password"


#how many worksheets?
$worksheetTotal = $workbook.sheets.count
#create System.DataTable
$dt = new-object "System.Data.DataTable"
$worksheetCurrent=1
#loop through the worksheets
Do {
    write-host $worksheetCurrent
    $startRow = 1
    $startColumn = 1
    $Worksheet = $Workbook.Worksheets.Item($worksheetCurrent)
    $tableName = $Workbook.Worksheets.Item($worksheetCurrent).name
    $Columns = $worksheet.UsedRange.Columns.Count
    [void]$dt.Columns.Add("Customer", [System.Type]::GetType("System.String"))
    [void]$dt.Columns.Add("Date", [System.Type]::GetType("System.String"))
    
    Do {
        $ColValue = $Worksheet.Cells.Item($startRow, $startColumn).Value()
        $startColumn++
        $dt.Columns.Add($ColValue)
        }
    While ($startColumn -le $Columns)

    # Instantiate some objects which will be needed
    $serverSMO = New-Object Microsoft.SqlServer.Management.Smo.Server($mysrvconn)
    $db = $serverSMO.Databases[$databaseName];
    $newTable = New-Object Microsoft.SqlServer.Management.Smo.Table ;
    $newTable.Parent = $db ;
    $newTable.Name = $tableName ;
    # Iterate the columns in the DataTable object and add dynamically named columns to the SqlServer Table object.	
    foreach($col in $dt.Columns)
    {
	    $sqlDataType = [Microsoft.SqlServer.Management.Smo.SqlDataType]::Varchar
	    $dataType = New-Object Microsoft.SqlServer.Management.Smo.DataType($sqlDataType);
	    $dataType.MaximumLength = 8000;
	    $newColumn = New-Object Microsoft.SqlServer.Management.Smo.Column($newTable,$col.ColumnName,$dataType);
	    $newColumn.DataType = $dataType;
	    $newTable.Columns.Add($newColumn);
    }
    $newTable.Create();
    #connect to SQL Server and import the system.data.table
    $SQLServerConnection = "server=$serverName;User ID=$uid;Password=$pwd;database=$databasename"
    $bulkCopy = new-object ("Data.SqlClient.SqlBulkCopy") $SQLServerConnection
    $bulkCopy.DestinationTableName = $tableName
    $bulkCopy.WriteToServer($dt)
    

$worksheetCurrent++
$dt.Columns.Clear()
}
while ($worksheetCurrent -le  $worksheetTotal)

$Excel.Quit()