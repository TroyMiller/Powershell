$ZoneName = "sql.local"


$AllDNSRecords = Get-DnsServerResourceRecord -ZoneName $ZoneName -RRType "A" 
ForEach ($DNSRecord in $AllDNSRecords) {
    $NewDNSRecord = Get-DnsServerResourceRecord -Name $DNSRecord.HostName -ZoneName $ZoneName -RRType "A"
    
    $NewDNSRecord.RecordData.IPv4Address = $NewDNSRecord.RecordData.IPv4Address -replace "10.3.1.", "10.4.0."
    $NewDNSRecord.RecordData.IPv4Address = $NewDNSRecord.RecordData.IPv4Address -replace "10.3.2.", "10.4.2."
    $NewDNSRecord.RecordData.IPv4Address = $NewDNSRecord.RecordData.IPv4Address -replace "10.3.3.", "10.4.3."
    $NewDNSRecord.RecordData.IPv4Address = $NewDNSRecord.RecordData.IPv4Address -replace "10.3.4.", "10.4.4."
    $NewDNSRecord.RecordData.IPv4Address = $NewDNSRecord.RecordData.IPv4Address -replace "10.3.250.", "10.4.5."
    $NewDNSRecord.RecordData.IPv4Address = $NewDNSRecord.RecordData.IPv4Address -replace "10.3.251.", "10.4.6."
    $NewDNSRecord.RecordData.IPv4Address = $NewDNSRecord.RecordData.IPv4Address -replace "10.3.10.", "10.4.10."
    
    Set-DnsServerResourceRecord -NewInputObject $NewDNSRecord -OldInputObject $DNSRecord -ZoneName $ZoneName -PassThru
    }