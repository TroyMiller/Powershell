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