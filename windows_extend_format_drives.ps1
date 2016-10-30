$credentials = get-credential
$format_extend_drives_scriptblock = {
    (gwmi Win32_cdromdrive).drive | %{$a = mountvol $_ /l;mountvol $_ /d;$a = $a.Trim();mountvol z: $a}
    foreach ($disk in get-wmiobject Win32_DiskDrive -Filter "Partitions = 0"){ 
       $disk.DeviceID
       $disk.Index
       "select disk "+$disk.Index+"`r attributes disk clear readonly`r online disk`r convert mbr`r clean`r create partition primary`r format fs=ntfs unit=65536 quick`r active`r assign letter=D" | diskpart
    }


    'list disk' | diskpart | ? {
      $_ -match 'disk (\d+)\s+online\s+\d+ .?b\s+\d+ [gm]b'
    } | % {
      $disk = $matches[1]
      "select disk $disk", "list partition" | diskpart | ? {
        $_ -match 'partition (\d+)'
      } | % { $matches[1] } | % {
        "select disk $disk", "select partition $_", "extend" | diskpart | Out-Null
      }
    }
}

Invoke-Command -ComputerName jmdwcp01.jewelersnt.local -ScriptBlock $format_extend_drives_scriptblock -AsJob -Credential $credentials
Get-Job | Wait-Job