Import-Module ActiveDirectory  
#Create array for users and results
$users = @() 
$results = @()

#Fill users array with only users that have managers and specific properties 
$users = Get-ADUser -LDAPFilter "(&(objectCategory=user)(objectClass=user)(!manager=*)(title=*))" -Properties Givenname, Surname, Displayname, office, telephonenumber, mail, samaccountname, manager, title, department, enabled  

Foreach ($user in $users){ 
	
	
	#Lookup SAMAccountName for users manager
	#$manager = (get-aduser (get-aduser $user.Samaccountname -Properties manager).manager).samaccountName 
	
	#Results test code below
	#Write-Host $user.SamAccountName, $user.GivenName, $user.Surname, $user.DisplayName, $user.Office, $user.telephonenumber, $user.mail, $user.Title, $user.Department, $manager
	
	#Builds Result in a format usable via CSV
	$result = new-object PSObject
	$result | Add-Member -MemberType NoteProperty -Name "SAMAccountName" -value $user.SamAccountName
	$result | Add-Member -MemberType NoteProperty -Name "GivenName" -value $user.GivenName
	$result | Add-Member -MemberType NoteProperty -Name "Surname" -value $user.Surname 
	$result | Add-Member -MemberType NoteProperty -Name "DisplayName" -value $user.DisplayName
	$result | Add-Member -MemberType NoteProperty -Name "Office" -value $user.Office
	$result | Add-Member -MemberType NoteProperty -Name "Telephone" -value $user.telephonenumber
	$result | Add-Member -MemberType NoteProperty -Name "Email" -value $user.mail
	$result | Add-Member -MemberType NoteProperty -Name "Title" -value $user.Title
	$result | Add-Member -MemberType NoteProperty -Name "Department" -value $user.Department
	$result | Add-Member -MemberType NoteProperty -Name "Enabled" -value $user.enabled
	#$result | Add-Member -MemberType NoteProperty -Name "Manager" -value $manager
	
	
	#Adds result for single user to larger array with all users
	$results += $result
} 
#Output $results array to CSV
$results | Export-Csv c:\Output\nomanagers_users.csv -NoTypeInformation