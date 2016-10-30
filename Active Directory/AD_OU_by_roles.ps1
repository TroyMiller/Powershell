import-module ActiveDirectory
$roles = Get-Content c:\scripts\server_roles.txt
$Envs = @("DEV","TEST","STAGE","PROD")

Foreach($env in $Envs){
    Write-Verbose "Starting deployment for $env" -Verbose
    $path = Get-ADOrganizationalUnit -filter * -SearchScope OneLevel | Where {$_.name -eq "Servers"}
    If(!(Get-ADOrganizationalUnit -filter * -SearchBase $path | Where {$_.name -eq $env})){
        Write-Verbose "Deploying OU for $env" -Verbose
        New-ADOrganizationalUnit -name $env -path $path
        }
    foreach($role in $roles){
        $role_path = $null
        $role_path = Get-ADOrganizationalUnit -filter * -SearchBase $path -SearchScope 1 | Where {$_.name -eq $env}
        If(!(Get-ADOrganizationalUnit -filter * -SearchBase $role_path | Where {$_.name -eq $role})){
            Write-Verbose "Deploying OU for $role in $env" -Verbose
            New-ADOrganizationalUnit -name $role -path $role_path
            }
    }
}

