
$oldgroup = read-host "Old AD Group Name?"
$newgroup = read-Host "New AD Group Name?"
$groupmembers = Get-ADGroupMember $oldgroup
Add-ADGroupMember -id $newgroup -members $groupmembers