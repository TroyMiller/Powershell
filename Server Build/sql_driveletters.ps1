<#Hi Guys sharing with you a script i developed to change the CD-ROM Drive in a newly provisioned Virtual Machine Using Hyper-V, You can modify the script accordingly for other drive letters.
Change CD ROM Drive Letter in Newly Built VM's to Z:\ Drive#>
 
<#Copy paste the one liner in an elevated Powershell window.#>
 
(gwmi Win32_cdromdrive).drive | %{$a = mountvol $_ /l;mountvol $_ /d;$a = $a.Trim();mountvol z: $a}

$drive = Get-WmiObject -Class win32_volume -Filter "DriveLetter = 'H:'"
Set-WmiInstance -input $drive -Arguments @{DriveLetter="Y:";}

$drive1 = Get-WmiObject -Class win32_volume -Filter "DriveLetter = 'E:'"
Set-WmiInstance -input $drive1 -Arguments @{DriveLetter="I:";}

$drive2 = Get-WmiObject -Class win32_volume -Filter "DriveLetter = 'F:'"
Set-WmiInstance -input $drive2 -Arguments @{DriveLetter="Q:";}

$drive3 = Get-WmiObject -Class win32_volume -Filter "DriveLetter = 'G:'"
Set-WmiInstance -input $drive3 -Arguments @{DriveLetter="E:";}

\\jmicfs01\tsoapps\McAfee\FramePkg.exe /install=agent /defaultpermissions
msiexec.exe /qb /i \\jmicfs01\TSOAPPS\LEMSS_Patchlink\LMAgentx64.msi SERVERIPADDRESS=jmicpl01.jewelersnt.local