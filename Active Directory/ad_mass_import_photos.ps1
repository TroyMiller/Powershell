Import-Module ActiveDirectory

$files = Get-ChildItem -file \\jewelersnt.local\Departments\Public\Employee_Photos\

foreach($file in $files){

write-host "Importing photo for:"$file.BaseName
$photo = ([Byte[]]$(Get-Content -Path $file.FullName -Encoding Byte -ReadCount 0))
$user = $file.BaseName
Set-ADUser $user -Replace @{thumbnailPhoto=$photo}
}
