
$computernames = Get-Content C:\tmp\servers.txt
Foreach ($computername in $computernames){
Write-Host "Removing Features from:" $computername
#Remove-OSFeature -ComputerName $computername WAS
Remove-OSFeature -ComputerName $computername NET-Win-CFAC
Start-sleep 10
#Write-Host "Restarting:" $computername
#Restart-Computer -ComputerName $computername -Force

}