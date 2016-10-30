$groups = get-adgroup -SearchBase "ou=Dev,ou=Servers,ou=Security Groups,dc=jewelersnt,dc=local" -Filter * 
$output = @()
foreach ($group in $groups){
    $Output += ($groups.name)
    }
$output | out-file c:\output\groups.txt