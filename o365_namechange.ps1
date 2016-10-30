$O365Cred = Get-Credential
$O365Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://ps.outlook.com/powershell -Credential $O365Cred -Authentication Basic -AllowRedirection
Import-PSSession $O365Session
Connect-MsolService -Credential $O365Cred

$OldUPN = Read-Host "Enter Old UPN (userid@jminsure.com)"
$NewUPN = Read-Host "Enter New UPN"

Set-MsolUserPrincipalName -UserPrincipalName $OldUPN -NewUserPrincipalName $NewUPN