﻿if (Get-Module -ListAvailable | Where-Object { $_.Name -eq "WebAdministration" }) {
 Import-Module WebAdministration 
} else {
 Add-PSSnapin WebAdministration
}
Get-WebApplication | select applicationPool, PhysicalPath, path

Get-Item IIS:\AppPools | Get-ChildItem | Select Name, State, StartMode, ManagedRuntimeVersion, ManagedPipelineMode

