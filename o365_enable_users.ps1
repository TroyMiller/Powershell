set-executionpolicy remotesigned
$O365Cred = Get-Credential
$O365Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://ps.outlook.com/powershell -Credential $O365Cred -Authentication Basic -AllowRedirection
Import-PSSession $O365Session
Connect-MsolService -Credential $O365Cred

$AccountSkuId = "jminsure:ENTERPRISEPACK" 
$UsageLocation = "US" 
$LicenseOptions = New-MsolLicenseOptions -AccountSkuId jminsure:ENTERPRISEPACK -DisabledPlans SHAREPOINTWAC,MCOSTANDARD,RMS_S_ENTERPRISE,EXCHANGE_S_ENTERPRISE
$Users = Import-Csv c:\Scripts\o365_users_v3.csv
$Users | ForEach-Object { 
Write-host "Enabling $_.UserPrincipalName"
Set-MsolUser -UserPrincipalName $_.UserPrincipalName -UsageLocation $UsageLocation 
Set-MsolUserLicense -UserPrincipalName $_.UserPrincipalName -AddLicenses $AccountSkuId 
Set-MsolUserLicense -UserPrincipalName $_.UserPrincipalName -LicenseOptions $LicenseOptions
}