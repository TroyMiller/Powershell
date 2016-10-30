#List of servers to upgrade
$servers = @()
$servers = Get-Content c:\scripts\puppetagents.txt

#Credentials used to invoke commands on servers
$admincreds = Get-Credential

#Puppet Version
$version = '1.4.1'
$puppetfilename = "puppet-agent-$version-x64.msi"

#Downloads Puppet Version to Internal webserver
$source = "https://downloads.puppetlabs.com/windows/$puppetfilename"
$destination = "\\jmpchy01\Apps\puppet_agent\$puppetfilename"
if(!(Test-Path $destination)){
    Write-Verbose "Downloading File from $source to $destination" -Verbose
    Invoke-WebRequest $source -OutFile $destination
}
else {
    Write-Verbose "$destination already exists" -Verbose
}


#Configures Download Locations for Install
$puppetsource = "http://jmpchy01.jewelersnt.local/Apps/puppet_agent/$puppetfilename"
$puppetdownload = "c:\temp\$puppetfilename"


$scriptBlock = {
    param ($puppetsource, $puppetdownload)

    #Removes file if it already exists
    Test-Path ($puppetdownload){Remove-Item -path $puppetdownload -Force}

    #Download Puppet Agent to C:\temp
    #Invoke-WebRequest $puppetsource -OutFile $puppetdownload
    #Above command requires PS3.0 or greater
    $client = New-Object System.Net.WebClient
    $client.DownloadFile($puppetsource,$puppetdownload)
    Start-Process -FilePath "msiexec.exe" -ArgumentList "/i $puppetdownload /qn /norestart" -wait
}


Foreach ($server in $servers){
    Write-Verbose "Deploying Puppet Agent upgrade to $server" -Verbose
    If(Test-Connection -count 2 -computer $server){
        New-PSSession -ComputerName $server -Credential $admincreds
        
        #ExecuteUpgrade on remote server
        Invoke-Command -ComputerName $server -ScriptBlock $scriptBlock -ArgumentList $puppetsource, $puppetdownload -AsJob -Credential $admincreds 
    }
}
Get-Job | Wait-Job
Write-Verbose "All Agents Upgraded" -Verbose


foreach ($server in $servers){
    Write-Verbose "Starting service on $server" -Verbose
    Invoke-Command -ComputerName $server -ScriptBlock {Start-Service -name puppet -Verbose} -Credential $admincreds


    #Replace with delete file
    Invoke-Command -ComputerName $server -ScriptBlock {param ($puppetdownload);Remove-Item -path $puppetdownload -Force} -ArgumentList $puppetdownload -Credential $admincreds

    #Remove Session after completed
    Write-Verbose "Removing session on $server" -Verbose
    Remove-PSSession -ComputerName $server
}
#Get all job results
Get-Job | Receive-Job | Out-GridView
#Clean-up Jobs
Get-Job | Remove-Job