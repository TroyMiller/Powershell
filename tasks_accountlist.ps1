﻿<#
.SYNOPSIS
	Get-ScheduledTasks will retrieve a list of scheduled tasks.
.DESCRIPTION
	Get-ScheduledTasks gets an exhaustive list of all scheduled tasks on the specified computer. It accomplishes this by created a schedule object and having that query the schedule service of the desired computer.
.PARAMETER ComputerName
	The name of the computer that you would like to gather information about. Defaults to the localhost.
.PARAMETER RootOnly
	When specified, the cmdlet will retrieve just the top level tasks. Usually the user specified ones.
.EXAMPLE
	Get-ScheduledTasks DC1 -RootOnly
	
	Actions        : WScript.exe C:\scripts\MyScript.vbs
	Path           : \Run My Script
	Enabled        : True
	Triggers       : CalendarTrigger
	Description    : The Scheduled task that runs my script.
	Author         : DOMAIN\User
	Name           : Run My Script
	NextRunTime    : 9/1/2013 3:00:00 AM
	LastRunTime    : 8/1/2013 3:00:00 AM
	LastTaskResult : 267014
.EXAMPLE
	Get-ADComputer -filter 'name -like "Workstation1*"' | select name | Get-ScheduledTasks
	
	This will return a long list of scheduled tasks from every computer in AD that meets the filter.
.INPUTS
.OUTPUTS
	Custom PSObject with properties: ComputerName,Actions,Path,Enabled,Triggers,Description,Author,Name,NextRunTime,LastRunTime,LastTaskResult
.NOTES
	Author: Twon of An
.LINK
	Schedule.Service
#>
Function Get-ScheduledTasks
{
	Param
	(
		[Alias("Computer","ComputerName")]
		[Parameter(Position=1,ValuefromPipeline=$true,ValuefromPipelineByPropertyName=$true)]
		[string[]]$Name = $env:COMPUTERNAME
		,
		[switch]$RootOnly = $false
	)
	Begin
	{
		$tasks = @()
		$schedule = New-Object -ComObject "Schedule.Service"
	}
	Process
	{
		Function Get-Tasks
		{
			Param($path)
			$out = @()
			$schedule.GetFolder($path).GetTasks(0) | % {
				$xml = [xml]$_.xml
				$out += New-Object psobject -Property @{
					"ComputerName" = $Computer
					"Name" = $_.Name
					"Path" = $_.Path
					"LastRunTime" = $_.LastRunTime
					"NextRunTime" = $_.NextRunTime
					"Actions" = ($xml.Task.Actions.Exec | % { "$($_.Command) $($_.Arguments)" }) -join "`n"
					"Triggers" = $(If($xml.task.triggers){ForEach($task in ($xml.task.triggers | gm | Where{$_.membertype -eq "Property"})){$xml.task.triggers.$($task.name)}})
					"Enabled" = $xml.task.settings.enabled
					"Author" = $xml.task.principals.Principal.UserID
					"Description" = $xml.task.registrationInfo.Description
					"LastTaskResult" = $_.LastTaskResult
					"RunAs" = $xml.task.principals.principal.userid
				}
			}
			If(!$RootOnly)
			{
				$schedule.GetFolder($path).GetFolders(0) | % {
					$out += get-Tasks($_.Path)
				}
			}
			$out
		}
		ForEach($Computer in $Name)
		{
			If(Test-Connection $computer -count 1 -quiet)
			{
				$schedule.connect($Computer)
				$tasks += Get-Tasks "\"
			}
			Else
			{
				Write-Error "Cannot connect to $Computer. Please check it's network connectivity."
				Break
			}
			$tasks
		}
	}
	End
	{
		[System.Runtime.Interopservices.Marshal]::ReleaseComObject($schedule) | Out-Null
		Remove-Variable schedule
	}
}


Import-module ActiveDirectory
$domain = Read-Host "Enter Domain Name"


$servers = Get-ADComputer -Filter {operatingsystem -like "*server*"} -properties Name,DNSHostname | sort Name
$Output = @()

ForEach ($server in $servers) {
   # Ping the machine to see if it's on the network
   $results = Get-WMIObject -query "select StatusCode from Win32_PingStatus where Address = '$($server.name)'"
   $responds = $false  
   ForEach ($result in $results) {
      # If the machine responds break out of the result loop and indicate success
      if ($result.statuscode -eq 0) {
         $responds = $true
         break
      }
   }
         If ($responds) {
      # Gather info from the server because it responds
      #$schtask = schtasks.exe /query /s $server.Name /V /FO CSV | ConvertFrom-Csv | Where { $_.TaskName -ne "TaskName" }
      #$services = $schtask | where { $_."Run As User" -like "$domain"} 
      write-output "Getting tasks from $($server.Name)"
      $services = Get-ScheduledTasks $($server.Name) -rootonly | Where-Object{$_.RunAs -like "$domain*"}
      $Output += $Services
   } else {
      # Let the user know we couldn't connect to the server
      Write-Output "$($server.name) does not respond"
   }
}
$Output | export-csv c:\Scripts\task_accounts.csv