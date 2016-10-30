$O365Cred = Get-Credential
$O365Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://ps.outlook.com/powershell -Credential $O365Cred -Authentication Basic -AllowRedirection
Import-PSSession $O365Session
Connect-MsolService -Credential $O365Cred

$userlist = Get-Content c:\scripts\bad_upn.txt

ForEach ($upn in $userlist)
{
    
    $newUPN = $upn.ToLower()
    Write-host $upn
    Write-host $NewUPN
    Set-MsolUserPrincipalName -UserPrincipalName $UPN -NewUserPrincipalName $NewUPN
}