### XML File share containing Features and Scheduled Tasks ####
$XML_Share = "\\jewelersnt.local\installs\tsoapps\server_builds"



#############################################
####### Environment Selection ###############
#############################################
$servername = hostname
#Sets variable to path script is currently running from
$dir = $MyInvocation.MyCommand.Path
$scriptpath = Split-Path $dir

# Edit This item to change the DropDown Values
[array]$DropDownArray_env = "dev-integration", "dev2", "dev3", "dev4", "qatest1", "qatest3", "qatest4", "qatest5", "qatest6", "stage"
[array]$DropDownArray_center = "Billing Center", "Policy Center", "Claim Center", "Contact Manager"

[System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
[System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")


$Form = New-Object System.Windows.Forms.Form

$Form.width = 300
$Form.height = 150
$Form.Text = ”Select Type of GW Center”
#########################################
### Source Dropdown #####
#########################################
$DropDown_env = new-object System.Windows.Forms.ComboBox
$DropDown_env.Location = new-object System.Drawing.Size(100,10)
$DropDown_env.Size = new-object System.Drawing.Size(130,30)

ForEach ($Item in $DropDownArray_env) {
	$DropDown_env.Items.Add($Item)| Out-Null
}

$Form.Controls.Add($DropDown_env)

$DropDownLabel_env = new-object System.Windows.Forms.Label
$DropDownLabel_env.Location = new-object System.Drawing.Size(15,15) 
$DropDownLabel_env.size = new-object System.Drawing.Size(100,20) 
$DropDownLabel_env.Text = "Type:"
$Form.Controls.Add($DropDownLabel_env)

###########################################################
#### Destination Dropdown ####
##########################################################
$DropDown_center = new-object System.Windows.Forms.ComboBox
$DropDown_center.Location = new-object System.Drawing.Size(100,40)
$DropDown_center.Size = new-object System.Drawing.Size(130,30)

ForEach ($Item in $DropDownArray_center) {
	$DropDown_center.Items.Add($Item)| Out-Null
}

$Form.Controls.Add($DropDown_center)


$DropDownLabel_center = new-object System.Windows.Forms.Label
$DropDownLabel_center.Location = new-object System.Drawing.Size(15,45) 
$DropDownLabel_center.size = new-object System.Drawing.Size(100,20) 
$DropDownLabel_center.Text = "Center:"
$Form.Controls.Add($DropDownLabel_center)




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

#$Type = $DropDown_env.SelectedItem.ToString()
$Center = $DropDown_center.SelectedItem.ToString()
$Environment = $DropDown_env.SelectedItem.ToString()

$output = [System.Windows.Forms.MessageBox]::Show("Center: " + $Center + "`r`n" + "Environment: " + $Environment, "Selections" , 1)
#Exit on Cancel on confirmation screen
if ($OUTPUT -eq "CANCEL"){
		exit
	}

Function ChangeCDtoZ()
{
	(gwmi Win32_cdromdrive).drive | %{$a = mountvol $_ /l;mountvol $_ /d;$a = $a.Trim();mountvol z: $a}
}

Function GWRegistry()
{
     if($center -eq "Billing Center") 
        { 
        $key = 'Registry::HKLM\SOFTWARE\Wow6432Node\Apache Software Foundation\Procrun 2.0\BillingCenter\Parameters\Java'
        test-path $key
        Get-itemProperty $key
        Set-ItemProperty $key Options -value "-Dcatalina.base=C:\guidewire","-Dcatalina.home=C:\guidewire","-Djava.endorsed.dirs=C:\guidewire\endorsed","-Djava.io.tmpdir=C:\guidewire\temp","-Djava.util.logging.manager=org.apache.juli.ClassLoaderLogManager","-Djava.util.logging.config.file=C:\guidewire\conf\logging.properties","-Dgw.server.mode=dev","-XX:PermSize=256m","-XX:MaxPermSize=256m","-Dgw.bc.env=$environment","-Dgw.bc.credfile=\\jewelersnt.local\jmpdfs\GWCredentials\qatest\guidewire.credentials","-Dgw.bc.cipherkeys=\\jewelersnt.local\jmpdfs\GWCredentials\qatest\guidewire.keys","-Dgw.bc.serverid=$servername","-Dcom.sun.management.jmxremote","-Dcom.sun.management.jmxremote.port=9012","-Dcom.sun.management.jmxremote.ssl=false","-Dcom.sun.management.jmxremote.authenticate=false","-Djava.net.preferIPv4Stack=true" -type MultiString
        Set-ItemProperty $key JvmMs -value "4096" -type DWord
        Set-ItemProperty $key JvmMx -value "4096" -type DWord
        }
		elseif($center -eq "Policy Center") 
        { 
        $key = 'Registry::HKLM\SOFTWARE\Wow6432Node\Apache Software Foundation\Procrun 2.0\PolicyCenter\Parameters\Java'
        test-path $key
        Get-itemProperty $key
        Set-ItemProperty $key Options -value "-Dcatalina.base=C:\guidewire","-Dcatalina.home=C:\guidewire","-Djava.endorsed.dirs=C:\guidewire\endorsed","-Djava.io.tmpdir=C:\guidewire\temp","-Djava.util.logging.manager=org.apache.juli.ClassLoaderLogManager","-Djava.util.logging.config.file=C:\guidewire\conf\logging.properties","-Dgw.server.mode=dev","-XX:PermSize=256m","-XX:MaxPermSize=256m","-Dgw.pc.env=$environment","-Dgw.pc.credfile=\\jewelersnt.local\jmpdfs\GWCredentials\qatest\guidewire.credentials","-Dgw.pc.cipherkeys=\\jewelersnt.local\jmpdfs\GWCredentials\qatest\guidewire.keys","-Dgw.pc.serverid=$servername","-Dcom.sun.management.jmxremote","-Dcom.sun.management.jmxremote.port=9012","-Dcom.sun.management.jmxremote.ssl=false","-Dcom.sun.management.jmxremote.authenticate=false","-Djava.net.preferIPv4Stack=true" -type MultiString
        Set-ItemProperty $key JvmMs -value "4096" -type DWord
        Set-ItemProperty $key JvmMx -value "4096" -type DWord
        }  
		elseif($center -eq "Claim Center") 
        { 
        $key = 'Registry::HKLM\SOFTWARE\Wow6432Node\Apache Software Foundation\Procrun 2.0\ClaimCenter\Parameters\Java'
        test-path $key
        Get-itemProperty $key
        Set-ItemProperty $key Options -value "-Dcatalina.base=C:\guidewire","-Dcatalina.home=C:\guidewire","-Djava.endorsed.dirs=C:\guidewire\endorsed","-Djava.io.tmpdir=C:\guidewire\temp","-Djava.util.logging.manager=org.apache.juli.ClassLoaderLogManager","-Djava.util.logging.config.file=C:\guidewire\conf\logging.properties","-Dgw.server.mode=dev","-XX:PermSize=256m","-XX:MaxPermSize=256m","-Dgw.cc.env=$environment","-Dgw.cc.credfile=\\jewelersnt.local\jmpdfs\GWCredentials\qatest\guidewire.credentials","-Dgw.cc.cipherkeys=\\jewelersnt.local\jmpdfs\GWCredentials\qatest\guidewire.keys","-Dgw.cc.serverid=$servername","-Dcom.sun.management.jmxremote","-Dcom.sun.management.jmxremote.port=9012","-Dcom.sun.management.jmxremote.ssl=false","-Dcom.sun.management.jmxremote.authenticate=false","-Djava.net.preferIPv4Stack=true" -type MultiString
        Set-ItemProperty $key JvmMs -value "2048" -type DWord
        Set-ItemProperty $key JvmMx -value "2048" -type DWord
        }  
        elseif($center -eq "Contact Manager") 
        { 
        $key = 'Registry::HKLM\SOFTWARE\Wow6432Node\Apache Software Foundation\Procrun 2.0\ContactManager\Parameters\Java'
        test-path $key
        Get-itemProperty $key
        Set-ItemProperty $key Options -value "-Dcatalina.base=C:\guidewire","-Dcatalina.home=C:\guidewire","-Djava.endorsed.dirs=C:\guidewire\endorsed","-Djava.io.tmpdir=C:\guidewire\temp","-Djava.util.logging.manager=org.apache.juli.ClassLoaderLogManager","-Djava.util.logging.config.file=C:\guidewire\conf\logging.properties","-Dgw.server.mode=dev","-XX:PermSize=256m","-XX:MaxPermSize=256m","-Dgw.ab.env=$environment","-Dgw.ab.credfile=\\jewelersnt.local\jmpdfs\GWCredentials\qatest\guidewire.credentials","-Dgw.ab.cipherkeys=\\jewelersnt.local\jmpdfs\GWCredentials\qatest\guidewire.keys","-Dgw.ab.serverid=$servername","-Dcom.sun.management.jmxremote","-Dcom.sun.management.jmxremote.port=9012","-Dcom.sun.management.jmxremote.ssl=false","-Dcom.sun.management.jmxremote.authenticate=false","-Djava.net.preferIPv4Stack=true" -type MultiString
        Set-ItemProperty $key JvmMs -value "2048" -type DWord
        Set-ItemProperty $key JvmMx -value "2048" -type DWord
        }  

}


Function InstallServices()
{
        
        if($center -eq "Billing Center") 
        { 
            cd \
            cd Guidewire\Bin
            start-process "cmd" "/c c:\guidewire\bin\service install BillingCenter"
        }
		elseif($center -eq "Policy Center") 
        { 
            cd \
            cd Guidewire\Bin
            start-process "cmd" "/c c:\guidewire\bin\service.bat install PolicyCenter"
        }  
		elseif($center -eq "Claim Center") 
        { 
            cd \
            cd Guidewire\Bin
            start-process "cmd" "/c c:\guidewire\bin\service.bat install ClaimCenter"
        }  
        elseif($center -eq "Contact Manager") 
        { 
            cd \
            cd Guidewire\Bin
            start-process "cmd" "/c c:\guidewire\bin\service.bat install ContactManager"
        }  
    
}

Function InstallScheduledTask()
{
        
        if($center -eq "Billing Center") 
        { 
            schtasks.exe /create /TN "Guidewire Log Cleanup" /XML $XML_Share\bc-gw-logfiles.xml
        }
		elseif($center -eq "Policy Center") 
        { 
           schtasks.exe /create /TN "Guidewire Log Cleanup" /XML $XML_Share\pc-gw-logfiles.xml
        }  
		elseif($center -eq "Claim Center") 
        { 
            schtasks.exe /create /TN "Guidewire Log Cleanup" /XML $XML_Share\cc-gw-logfiles.xml
        }  
        elseif($center -eq "Contact Manager") 
        { 
            schtasks.exe /create /TN "Guidewire Log Cleanup" /XML $XML_Share\cm-gw-logfiles.xml
        }  
    
}

Function CreateShares()
{
        
        if($center -eq "Billing Center") 
        { 
        New-Item c:\tmp\gwlogs\BillingCenter -Type Directory
        (Get-WmiObject Win32_Share -List).Create("c:\tmp\gwlogs\BillingCenter", "BC Logs", 0)
        }
		elseif($center -eq "Policy Center") 
        { 
        New-Item c:\tmp\gwlogs\PolicyCenter -Type Directory
        (Get-WmiObject Win32_Share -List).Create("c:\tmp\gwlogs\PolicyCenter", "PC Logs", 0)
        }  
		elseif($center -eq "Claim Center") 
        { 
        New-Item c:\tmp\gwlogs\ClaimCenter -Type Directory
        (Get-WmiObject Win32_Share -List).Create("c:\tmp\gwlogs\ClaimCenter", "CC Logs", 0)
        }  
        elseif($center -eq "Contact Manager") 
        { 
        New-Item c:\tmp\gwlogs\ContactManager -Type Directory
        (Get-WmiObject Win32_Share -List).Create("c:\tmp\gwlogs\ContactManager", "CM Logs", 0)
        }  
    
}

Function RemoveLinks()
{
        
        if($center -eq "Billing Center") 
        { 
        #del "c:\Users\Public\Desktop\BillingCenter Service Config.lnk"
        del "c:\Users\Public\Desktop\PolicyCenter Service Config.lnk"
        del "c:\Users\Public\Desktop\Contact Manager Service Config.lnk"
        del "c:\Users\Public\Desktop\ClaimCenter Service Config.lnk"
        }
		elseif($center -eq "Policy Center") 
        { 
        del "c:\Users\Public\Desktop\BillingCenter Service Config.lnk"
        #del "c:\Users\Public\Desktop\PolicyCenter Service Config.lnk"
        del "c:\Users\Public\Desktop\Contact Manager Service Config.lnk"
        del "c:\Users\Public\Desktop\ClaimCenter Service Config.lnk"
        }  
		elseif($center -eq "Claim Center") 
        { 
        del "c:\Users\Public\Desktop\BillingCenter Service Config.lnk"
        del "c:\Users\Public\Desktop\PolicyCenter Service Config.lnk"
        del "c:\Users\Public\Desktop\Contact Manager Service Config.lnk"
        #del "c:\Users\Public\Desktop\ClaimCenter Service Config.lnk"
        }  
        elseif($center -eq "Contact Manager") 
        { 
        del "c:\Users\Public\Desktop\BillingCenter Service Config.lnk"
        del "c:\Users\Public\Desktop\PolicyCenter Service Config.lnk"
        #del "c:\Users\Public\Desktop\Contact Manager Service Config.lnk"
        del "c:\Users\Public\Desktop\ClaimCenter Service Config.lnk"
        }  
    
}
Function InstallAVPatching()
 {
    #Install McAfee and Wait till completed
\\jewelersnt.local\installs\tsoapps\McAfee\FramePkg.exe /install=agent /s | Out-Null

#Install Patchlink and wait till completed
\\jewelersnt.local\installs\TSOAPPS\LEMSS_Patchlink\lmsetupx64.exe install SERVERIPADDRESS=jmicpl01.jewelersnt.local MODULELIST="VulnerabilityManagement" | Out-Null
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
 
#Runs Script
ChangeCDtoZ
InstallServices
CreateShares
RemoveLinks
InstallAVPatching
InstallScheduledTask
AddAdministrators
GWRegistry