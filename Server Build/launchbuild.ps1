### Script to pull server build scripts from SVN and Launch

$storageDir = "c:\scripts\"

If(!(Test-Path -path $storageDir))
    {
     New-Item C:\Scripts -Directory
     }


$webclient = New-Object System.Net.WebClient
$url = "http://jmpscc01.jewelersnt.local/svn/scripts/trunk/Admin%20Scripts/Server%20Build/gwsetup.ps1"
$file = "$storageDir\build.ps1"
$webclient.DownloadFile($url,$file)


Start-Job -FilePath c:\Scripts\build.ps1

#Wait for all jobs
Get-Job | Wait-Job
	
#Get all job results
Get-Job | Receive-Job | Out-GridView