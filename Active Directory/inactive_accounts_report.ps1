#Report settings  [string[]]
#Param(
#    
#    [switch]$sendmail,
#    $timespan = '90.00:00:00',
#    $to =@('tmiller@jminsure.com','bgunckel@jminsure.com','dwarner@jminsure.com', 'lmcmorran@jminsure.com')
#    $from = 'jmpadc01@jminsure.com',
#    $smtpserver = 'jmicmail.jewelersnt.local'
#)
Import-Module ActiveDirectory

#Generate Reports
$timespan = '90.00:00:00'
 $to =@('tmiller@jminsure.com','bgunckel@jminsure.com','dwarner@jminsure.com')
$from = 'jmpadc01@jminsure.com'
$smtpserver = 'jmicmail.jewelersnt.local'

Search-ADAccount -AccountInactive -UsersOnly -TimeSpan $timespan | Select-Object SamAccountName,Enabled,PasswordNeverExpires,LastLogonDate,DistinguishedName | Sort-Object SamAccountName | export-csv c:\temp\users.csv -force
Search-ADAccount -AccountInactive -ComputersOnly -TimeSpan $timespan | Select-Object Name,Enabled,LastLogonDate,DistinguishedName | Sort-Object Name | export-csv c:\temp\computers.csv -force
$rpt1 = 'c:\temp\users.csv'
$rpt2 = 'c:\temp\computers.csv'

# combine fragments into one report - point to web based style sheet.
# style sheet used her is a dem and can be downloaded and modified.
# style sheet can be embedded in report or placed on corporate intranet server on a share.
$reportbanner="<h1>AD Inactive Accounts Reports</h1>"
$reportHTML=ConvertTo-HTML `
               -Body "$reportbanner" `
               -Title 'AD Inactive Accounts Reports' `

	
 	       
#$reportHTML | Out-File .\report.htm
$sendmail = $true
if($sendmail){
Write-Warning "sending"
     $htmlBody = $reportHTML | Out-String
     Send-MailMessage `
          -to $to `
          -from $from `
          -smtpserver $smtpserver `
          -subject 'AD Inactive Accounts Reports' `
          -body $htmlBody `
          -Attachments $rpt1,$rpt2 `
          -BodyAsHtml
}
