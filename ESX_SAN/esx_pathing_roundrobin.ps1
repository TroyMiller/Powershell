﻿Get-VMHost -name jmd* | Get-ScsiLun -LunType disk | Where {$_.MultipathPolicy -notlike "RoundRobin"} | Where {$_.CapacityGB -ge 4096} | Set-Scsilun -MultiPathPolicy RoundRobin