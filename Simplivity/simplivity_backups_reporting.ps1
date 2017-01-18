#Not ready for LogicMonitor

$username = 'user'
$password = 'fakepass'
$ovc = "ovc_ip_address"
$csv_file = 'c:\logs\backups.csv'
$results = @()

#Ignore Self Signed Certificates and set TLS
Try {
Add-Type @"
       using System.Net;
       using System.Security.Cryptography.X509Certificates;
              public class TrustAllCertsPolicy : ICertificatePolicy {
              public bool CheckValidationResult(
                     ServicePoint srvPoint, X509Certificate certificate,
                     WebRequest request, int certificateProblem) {
                     return true;
              }
       }
"@
       [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
       [System.Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
} 
Catch {
}                                                                                                                                                                          

#Builds Call to retrieve API access token
$uri = "https://" + $ovc + "/api/oauth/token"
$base64 = [Convert]::ToBase64String([System.Text.UTF8Encoding]::UTF8.GetBytes("simplivity:"))
$body =@{grant_type="password";username="$username";password="$password"}
$headers = @{}
$headers.Add("Authorization", "Basic $base64")
$response = Invoke-RestMethod -Uri $uri -Headers $headers -Body $body -Method Post

#Creates headers with Access Token
$atoken = $response.access_token
$headers = @{}
$headers.Add("Authorization", "Bearer $atoken")

#Gather list of VMs and associated IDs
$uri = "https://" + $ovc + "/api/virtual_machines"
$response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
$response = $response.virtual_machines | select name, id

Foreach ($vm in $response){
#Pulls backup information for each VM in the previous response
$backup_uri = "https://" + $ovc + "/api/virtual_machines/$($vm.id)/backups"
$backup_response = Invoke-RestMethod -Uri $backup_uri -Headers $headers -Method Get

$results += $backup_response.backups | select virtual_machine_name, state, sent, name, created_at, size, application_consistent -first 1

#Building Output for LM
$output = $backup_response.backups | select virtual_machine_name, state, sent, name, created_at, size, application_consistent -first 1 
write-host $output
}
#Output for non-LM usage
$results | export-csv $csv_file
$results | Out-GridView 
