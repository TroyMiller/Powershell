Import-Module ServerManager

### XML File share containing Features and Scheduled Tasks ####
$XML_Share = "\\jewelersnt.local\installs\tsoapps\server_builds"

#############################################
####### Environment Selection ###############
#############################################

#Sets variable to path script is currently running from
$dir = $MyInvocation.MyCommand.Path
$scriptpath = Split-Path $dir

# Edit This item to change the DropDown Values
[array]$DropDownArray_dst = "APP", "AUTH", "CMS", "DGN", "IDP", "IMG", "RAT","SVC", "WAP"

[System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
[System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")


$Form = New-Object System.Windows.Forms.Form

$Form.width = 300
$Form.height = 150
$Form.Text = ”Select Type of Server”
$DropDown_dst = new-object System.Windows.Forms.ComboBox
$DropDown_dst.Location = new-object System.Drawing.Size(100,40)
$DropDown_dst.Size = new-object System.Drawing.Size(130,30)

ForEach ($Item in $DropDownArray_dst) {
	$DropDown_dst.Items.Add($Item)| Out-Null
}

$Form.Controls.Add($DropDown_dst)


$DropDownLabel_dst = new-object System.Windows.Forms.Label
$DropDownLabel_dst.Location = new-object System.Drawing.Size(15,45) 
$DropDownLabel_dst.size = new-object System.Drawing.Size(100,20) 
$DropDownLabel_dst.Text = "Server Type:"
$Form.Controls.Add($DropDownLabel_dst)




#########################################
#### Select/Cancel Buttons
#########################################

$Button = new-object System.Windows.Forms.Button
$Button.Location = new-object System.Drawing.Size(10,80)
$Button.Size = new-object System.Drawing.Size(100,20)
$Button.Text = "Select"
$Button.Add_Click({
	$Form.DialogResult = "OK"
	$Form.close()
})
$form.Controls.Add($Button)

$CancelButton = New-Object System.Windows.Forms.Button
$CancelButton.Location = New-Object System.Drawing.Size(130,80)
$CancelButton.Size = New-Object System.Drawing.Size(100,20)
$CancelButton.Text = "Cancel"
$CancelButton.Add_Click({
	$Form.DialogResult = "Cancel"
	$Form.close()
})
$Form.Controls.Add($CancelButton)

$Form.Add_Shown({$Form.Activate()})
$result = $Form.ShowDialog()



#Exit script if cancel on selection screen
If ($result -eq "Cancel"){
	exit
}

#$Type = $DropDown_src.SelectedItem.ToString()
$srvtype = $DropDown_dst.SelectedItem.ToString()

$output = [System.Windows.Forms.MessageBox]::Show("Server Type: " + $srvtype, "Selections" , 1)
#Exit on Cancel on confirmation screen
if ($OUTPUT -eq "CANCEL"){
		exit
	}


Function ChangeCDtoZ()
{
	(gwmi Win32_cdromdrive).drive | %{$a = mountvol $_ /l;mountvol $_ /d;$a = $a.Trim();mountvol z: $a}
}

Function InstallFeatures()
{
        
        if($srvtype -eq "APP") 
        { 
            $feature = Import-Clixml $XML_Share\app-features.xml
            $feature | Add-WindowsFeature

        }
		elseif($srvtype -eq "AUTH") 
        { 
            $feature = Import-Clixml $XML_Share\auth-features.xml
            $feature | Add-WindowsFeature

        }  
		elseif($srvtype -eq "DGN") 
        { 
            $feature = Import-Clixml $XML_Share\dgn-features.xml
            $feature | Add-WindowsFeature

        }  
        elseif($srvtype -eq "IDP") 
        { 
            $feature = Import-Clixml $XML_Share\idp-features.xml
            $feature | Add-WindowsFeature

        }  
        elseif($srvtype -eq "IMG") 
        { 
            $feature = Import-Clixml $XML_Share\img-features.xml
            $feature | Add-WindowsFeature

        }  
        elseif($srvtype -eq "RAT") 
        { 
            $feature = Import-Clixml $XML_Share\rat-features.xml
            $feature | Add-WindowsFeature

        } 
        elseif($srvtype -eq "SVC") 
        { 
            $feature = Import-Clixml $XML_Share\svc-features.xml
            $feature | Add-WindowsFeature

        }   
        elseif($srvtype -eq "WAP") 
        { 
            $feature = Import-Clixml $XML_Share\wap-features.xml
            $feature | Add-WindowsFeature

        }  
        elseif($srvtype -eq "CMS") 
        { 
            $feature = Import-Clixml $XML_Share\cms-features.xml
            $feature | Add-WindowsFeature

        }  
}

Function InstallAVPatching()
 {
    #Install McAfee and Wait till completed
\\jewelersnt.local\installs\tsoapps\McAfee\FramePkg.exe /install=agent /s | Out-Null

#Install Patchlink and wait till completed
\\jewelersnt.local\installs\TSOAPPS\LEMSS_Patchlink\lmsetupx64.exe install SERVERIPADDRESS=jmicpl01.jewelersnt.local MODULELIST="VulnerabilityManagement" | Out-Null
 }

Function InstallWireshark()
{
\\jewelersnt.local\installs\TSOAPPS\Wireshark\Wireshark-win64-1.12.3.exe | Out-Null
}

Function InstallNotepadPlusPlus()
{
\\jewelersnt.local\installs\TSOAPPS\NotepadPlusPlus\npp.6.7.3.Installer.exe /S | Out-Null
}

Function AddAdministrators()
 {
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
 
    
 }
Function InstallScheduledTask()
{
        if($srvtype -eq "APP") 
        { 
        schtasks.exe /create /TN "IIS Log Cleanup" /XML \$XML_Share\iis-logfiles.xml

        }
		elseif($srvtype -eq "AUTH") 
        { 
           schtasks.exe /create /TN "AD LDS Log Cleanup" /XML $XML_Share\auth-logfiles.xml

        }  
		elseif($srvtype -eq "DGN") 
        { 
           schtasks.exe /create /TN "Thunderhead Log Cleanup" /XML $XML_Share\dgn-logfiles.xml

        }  
        elseif($srvtype -eq "IDP") 
        { 
            schtasks.exe /create /TN "IDP Log Cleanup" /XML $XML_Share\idp-logfiles.xml

        }  
        elseif($srvtype -eq "IMG") 
        { 
            schtasks.exe /create /TN "IMG Log Cleanup" /XML $XML_Share\img-logfiles.xml

        }  
        elseif($srvtype -eq "RAT") 
        { 
            schtasks.exe /create /TN "Ratabase Log Cleanup" /XML $XML_Share\rat-logfiles.xml

        } 
        elseif($srvtype -eq "SVC") 
        { 
            schtasks.exe /create /TN "IIS Log Cleanup" /XML $XML_Share\iis-logfiles.xml

        }   
        elseif($srvtype -eq "WAP") 
        { 
            schtasks.exe /create /TN "IIS Log Cleanup" /XML $XML_Share\iis-logfiles.xml

        }  
        elseif($srvtype -eq "CMS") 
        { 
            schtasks.exe /create /TN "IIS Log Cleanup" /XML $XML_Share\iis-logfiles.xml

        }  
        
}
#Runs Script
ChangeCDtoZ
InstallFeatures
InstallAVPatching
InstallNotePadPlusPlus
InstallScheduledTask
AddAdministrators
InstallWireshark