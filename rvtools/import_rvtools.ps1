Add-Type -AssemblyName Microsoft.VisualBasic

function Get-FileName($initialDirectory)
{
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null
    
    $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $OpenFileDialog.initialDirectory = $initialDirectory
    $OpenFileDialog.ShowDialog() | Out-Null
    $OpenFileDialog.filename
}

$ImportScriptBlock = {
    Param($filepath, $worksheetCurrent, $date, $customer)
    
    $Excel = New-Object -ComObject Excel.Application
    $Workbook = $Excel.Workbooks.Open($filepath)
    $ColValues = @()
    
    #Create DataTable
    $dt = new-object "System.Data.DataTable"

    #some variables
    $serverName = "sql\sqlexpress";
    $databaseName = "rvtools" ;
    $uid = "rvtools";
    $pwd = "password";

    $Worksheet = $Workbook.Worksheets.Item($worksheetCurrent)
    $tableName = $Workbook.Worksheets.Item($worksheetCurrent).name
    $Columns = $worksheet.UsedRange.Columns.Count
    $startColumn = 1
    $startRow = 1

    [void]$dt.Columns.Add("Customer", [System.Type]::GetType("System.String"))
    [void]$dt.Columns.Add("Date", [System.Type]::GetType("System.String"))
    
    #Create DataTable with Columns
    Do {
        $ColValue = $Worksheet.Cells.Item($startRow, $startColumn).Value()
        $startColumn++
        $dt.Columns.Add($ColValue)
        }
    While ($startColumn -le $Columns)

    #Reset to start on Row 2, Column 1 for capturing data
    $startColumn = 1
    $startRow = 2
    
    #Fill DataTable with Row Values
    Do {   
        $ColValues = @()
        $ColValues += $Customer
        $ColValues += $Date
        
        Do {

            $ColValues += $Worksheet.Cells.Item($startRow, $startColumn).Value()
            $startColumn++
        
        }
        While ($startColumn -le $Columns)
        
        $startRow++
        $startColumn = 1
        $dt.Rows.Add($ColValues)
    }
    While ($Worksheet.Cells.Item($startRow,1).Value() -ne $null)
    
    #Close Excel File
    $Excel.Quit()
    
    #connect to SQL Server and import the system.data.table
    $SQLServerConnection = "server=$serverName;User ID=$uid;Password=$pwd;database=$databasename"
    $bulkCopy = new-object ("Data.SqlClient.SqlBulkCopy") $SQLServerConnection
    $bulkCopy.DestinationTableName = $tableName
    $bulkCopy.WriteToServer($dt)
    Write-Verbose "Writing $tableName values to SQL" -Verbose
    
    #Close Excel
    $Excel.Quit()
    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($Excel)
    Remove-Variable Excel

}

#create object to open Excel workbook
$filepath = Get-FileName "c:\temp"
$Excel = New-Object -ComObject Excel.Application
$Workbook = $Excel.Workbooks.Open($filepath)

#Set date based on file creation
$filedate = (Get-item $filepath).creationtime
$date = $filedate.ToString("MM/dd/yyyy")

#Prompt for Customer Name
$customer = [Microsoft.VisualBasic.Interaction]::InputBox('Enter Customer Name', 'Customer Name', "Unknown")

#how many worksheets?
$worksheetTotal = $workbook.sheets.count
$worksheetCurrent=1


#loop through the worksheets
Foreach ($sheet in $workbook.worksheets) {
    Start-Job $ImportScriptBlock -ArgumentList $filepath,$worksheetCurrent, $date, $customer
    $worksheetCurrent++
#    $dt.Columns.Clear()
#    $dt.Rows.Clear()
}
#while ($worksheetCurrent -le  $worksheetTotal)
# Wait for it all to complete
While (Get-Job -State "Running")
{
  $runningjobs = (Get-Job -State "Running").Count
  Write-Verbose "Currently $runningjobs of $worksheettotal remaining" -Verbose
  Start-Sleep 10
}

# Getting the information back from the jobs
Get-Job | Out-GridView

#Close Excel
$Excel.Quit()
[System.Runtime.Interopservices.Marshal]::ReleaseComObject($Excel)
Remove-Variable Excel