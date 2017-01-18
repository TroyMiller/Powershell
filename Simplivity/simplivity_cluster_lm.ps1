$username = 'user'
$password = 'password'

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

$ovc = "192.168.1.31"
$uri = "https://" + $ovc + "/api/oauth/token"
$base64 = [Convert]::ToBase64String([System.Text.UTF8Encoding]::UTF8.GetBytes("simplivity:"))
$body =@{grant_type="password";username="$username";password="$password"}
$headers = @{}
$headers.Add("Authorization", "Basic $base64")
$response = Invoke-RestMethod -Uri $uri -Headers $headers -Body $body -Method Post
$atoken = $response.access_token
$headers = @{}
$headers.Add("Authorization", "Bearer $atoken")
 $uri = "https://" + $ovc + "/api/ReplicaInfo"
$response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
$stats = ConvertTo-Json $response
write-host $stats