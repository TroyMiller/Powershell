##Simplivity Monitoring for LogicMonitor

$username = 'user'
$password = 'password'
$ovc = "ovc"
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

$uri = "https://" + $ovc + "/api/oauth/token"
$base64 = [Convert]::ToBase64String([System.Text.UTF8Encoding]::UTF8.GetBytes("simplivity:"))
$body =@{grant_type="password";username="$username";password="$password"}
$headers = @{}
$headers.Add("Authorization", "Basic $base64")
$response = Invoke-RestMethod -Uri $uri -Headers $headers -Body $body -Method Post
$atoken = $response.access_token
$headers = @{}
$headers.Add("Authorization", "Bearer $atoken")
$uri = "https://" + $ovc + "/api/virtual_machines"
$response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get


$response = $response.virtual_machines | select name, id


Foreach ($vm in $response){

#write-host $vm.name
#write-host $vm.id
$uri = "https://" + $ovc + "/api/virtual_machines/$vmid/backups?top=1"
$response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
$results = $response.backups | select virtual_machine_name, state, sent, name, created_at, size, application_consistent -first 1

$virtual_machine_name = $results.virtual_machine_name
$state = $results.state
$sent = $results.sent
$name = $results.name
$created_at = $results.created_at
$size = $results.size
$consistent = $results.application_consistent

# Convert worded results to integers
switch -Exact ($state)
    {
        "PROTECTED" {$state="0"}
        "NEW" {$state="1"}
        "QUEUED" {$state="2"}
        "SAVING" {$state="3"}
        "DEGRADED" {$state="4"}
        default {$state="8"}
    }
switch -Exact ($consistent)
    {
        "True" {$consistent="1"}
        "False" {$consistent="0"}
        default {$consistent="2"}
    }
write-host $vm.name
write-host "$($vm.id).State=$state"
write-host "$($vm.id).sent=$sent"
write-host "$($vm.id).name=$name"
write-host "$($vmid).created_at=$created_at"
write-host "$($vmid).size=$size"
write-host "$($vm.id).application_consistent=$consistent"


}
