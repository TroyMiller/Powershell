<#Hi Guys sharing with you a script i developed to change the CD-ROM Drive in a newly provisioned Virtual Machine Using Hyper-V, You can modify the script accordingly for other drive letters.
Change CD ROM Drive Letter in Newly Built VM's to Z:\ Drive#>
 
<#Copy paste the one liner in an elevated Powershell window.#>
 
(gwmi Win32_cdromdrive).drive | %{$a = mountvol $_ /l;mountvol $_ /d;$a = $a.Trim();mountvol z: $a}


#Install McAfee and Wait till completed
\\jewelersnt.local\installs\tsoapps\McAfee\FramePkg.exe /install=agent /s | Out-Null

#Install Patchlink and wait till completed
\\jewelersnt.local\installs\TSOAPPS\LEMSS_Patchlink\lmsetupx64.exe install SERVERIPADDRESS=jmicpl01.jewelersnt.local MODULELIST="VulnerabilityManagement" | Out-Null

#Add Server admin group
$server = hostname
if ($server -like "JMP*") {
    $admingroup_env = 'gl-IT-LocalServerAdmin-Prod'
}
if ($server -like "JMS*") {
    $admingroup_env = 'gl-IT-LocalServerAdmin-Stage'
}
if ($server -like "JMT*") {
    $admingroup_env = 'gl-IT-LocalServerAdmin-Test'
}
if ($server -like "JMD*") {
    $admingroup_env = 'gl-IT-LocalServerAdmin-Dev'
}
$adminGroup = [ADSI]"WinNT://localhost/Administrators"
$adminGroup.add("WinNT://jewelersnt.local/gl-IT-$server-Admin")
$adminGroup.add("WinNT://jewelersnt.local/$admingroup_env")
 
