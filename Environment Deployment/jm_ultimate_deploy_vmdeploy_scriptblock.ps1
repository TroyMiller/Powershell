###################################
#Script Block that Builds VMs
###################################
$deploy_VMs_scriptblock = {
				param($vCS, $cred, $vms, $log, $progress)
				
				#simple helper object to track job progress, we will dump it to $clustername-progres.csv for the parent process to read every minute
				$job_progress = New-Object PSObject
				
				$job_progress | Add-Member -Name "PWROK" -Value 0 -MemberType NoteProperty
				$job_progress | Add-Member -Name "PWRFAIL" -Value 0 -MemberType NoteProperty
                $job_progress | Add-Member -Name "DPLFAIL" -Value 0 -MemberType NoteProperty
				$job_progress | Add-Member -Name "CUSTSTART" -Value 0 -MemberType NoteProperty
				$job_progress | Add-Member -Name "CUSTOK" -Value 0 -MemberType NoteProperty
				$job_progress | Add-Member -Name "CUSTFAIL" -Value 0 -MemberType NoteProperty
				$job_progress | Export-Csv -Path $progress -NoTypeInformation
				
				#scriptblock is started as separate PS (not PowerCLI!), completely autonomous process, so we really need to load the snap-in
				$vmsnapin = Get-PSSnapin VMware.VimAutomation.Core -ErrorAction SilentlyContinue
				$Error.Clear()
				if ($vmsnapin -eq $null){
					Add-PSSnapin VMware.VimAutomation.Core 
					if ($error.Count -ne 0){
						(Get-Date -Format ("[yyyy-MM-dd HH:mm:ss] ")) + "Error: Loading PowerCLI" | out-file $log -Append
						exit
					}
				}
				
				#and connect vCenter
				connect-viserver -server $vCS -Credential $cred 2>&1 | out-null
				if ($error.Count -eq 0){
					(Get-Date -Format ("[yyyy-MM-dd HH:mm:ss] ")) + ":Info: vCenter $vCS successfully connected" | out-file $log -Append
					
					#array to store cloned OS customizations that we need to clean-up once script finishes
					$cloned_2b_cleaned = @()
					#hash table to store new-vm async tasks
					$newvm_tasks = @{}
					
					#this is needed as timestamp for searching the logs for customization events at the end of this scriptblock
					$start_events = get-date
					$started_vms = @()
                    
					#array of customization status values and a timeout for customization in seconds (it is exactly 2hrs, feel free to reduce it)
					$Customization_In_Progress = @("CustomizationNotStarted", "CustomizationStarted")
					[int]$timeout_sec = 7200
					
					#after we sanitized input, something must be there
					$total_vms = $vms.count
					
                    #so I'm not afraid to reach for element [0] of this array
					$vmhosts = get-vmhost -location $vms[0].cluster -state "connected"
					
					$total_hosts = ($vmhosts.count) * 4
					$batch = 0
					
                    #split vms to batches for deployment, each batch has $total_hosts concurrent deployments (so a single host deploys only one vm at a time)
					while ($batch -lt $total_vms){ #scan array until we run out of vms to deploy
							$index =0 
							while ($index -lt $total_hosts){ #in batches equal to number of available hosts
								if ($vms[($batch + $index)].name) { #check if end of array
                                
                                #Check if resource pool exists, create if doesn't
                                if (!(get-resourcepool | where {$_.name -eq ($vms[($batch + $index)].environment)})){
                                    New-ResourcePool -Name ($vms[($batch + $index)].environment) -Location ($vms[($batch + $index)].cluster) | Out-Null
                                    (Get-Date -Format ("[yyyy-MM-dd HH:mm:ss] ")) + ":Info: Created resource pool $($vms[($batch + $index)].environment)!" | out-file $log -Append
                                }
                                
                                #Check if VM folder exists
                                if (!(Get-View -viewtype folder -filter @{"name"=($vms[($batch + $index)].environment)})){
                                    (Get-View -viewtype folder -filter @{"name"="Environment"}).CreateFolder($vms[($batch + $index)].environment) | Out-Null
                                    (Get-Date -Format ("[yyyy-MM-dd HH:mm:ss] ")) + ":Info: Created VM folder $($vms[($batch + $index)].environment)!" | out-file $log -Append
                                }

									if (!(get-vm | where {$_.name -eq ($vms[($batch + $index)].name)})){ #check if vm name is already taken
										
										#if "none" detected as IP address, we do not set it via OSCustomizationSpec, whatever is in template will be inherited (hopefully DHCP)
                                        if ($vms[($batch + $index)].ip -match "none"){
											(Get-Date -Format ("[yyyy-MM-dd HH:mm:ss] ")) + ":Info: No IP config for $($vms[($batch + $index)].name) deploying with DHCP!" | out-file $log -Append
											(Get-Date -Format ("[yyyy-MM-dd HH:mm:ss] ")) + ":Info: Starting async deployment for $($vms[($batch + $index)].name)" | out-file $log -Append
											$newvm_tasks[(new-vm -name $($vms[($batch + $index)].name) -template $(get-template -name $($vms[($batch + $index)].template)) -vmhost $vmhosts[$index] -oscustomizationspec $(get-oscustomizationspec -name $($vms[($batch + $index)].oscust)) -datastore $(get-datastorecluster -name $($vms[($batch + $index)].datastorecluster)) -location $(get-folder -name $($vms[($batch + $index)].environment)) -ResourcePool $(get-resourcepool -name $($vms[($batch + $index)].environment))  -RunAsync -ErrorAction SilentlyContinue).id] = $($vms[($batch + $index)].name)
                                            #catch new-vm errors - if any
                                            if ($error.count) {
                                                $error[0].exception | out-file $log -Append
                                                $job_progress.DPLFAIL++
                                                $error.clear()
                                            }
																							
										}
										else {
											#clone the "master" OS Customization Spec, then use it to apply vm specific IP configuration (for 1st vNIC ONLY!)
											(Get-Date -Format ("[yyyy-MM-dd HH:mm:ss] ")) + ":Info: Cloning OS customization for $($vms[($batch + $index)].name)" | out-file $log -Append
											$cloned_oscust = Get-OSCustomizationSpec $vms[($batch + $index)].oscust | New-OSCustomizationSpec -name "$($vms[($batch + $index)].oscust)_$($vms[($batch + $index)].name)"
											
											#for Linux systems you can not set DNS via OS Customization Spec, so set it to "none"
											if ($vms[($batch + $index)].dns1 -match "none") {
												Set-OSCustomizationNicMapping -OSCustomizationNicMapping ($cloned_oscust | Get-OscustomizationNicMapping) -Position 1 -IpMode UseStaticIp -IpAddress $vms[($batch + $index)].ip -SubnetMask $vms[($batch + $index)].mask -DefaultGateway $vms[($batch + $index)].gw | Out-Null
											}
											else {
												Set-OSCustomizationNicMapping -OSCustomizationNicMapping ($cloned_oscust | Get-OscustomizationNicMapping) -Position 1 -IpMode UseStaticIp -IpAddress $vms[($batch + $index)].ip -SubnetMask $vms[($batch + $index)].mask -DefaultGateway $vms[($batch + $index)].gw -Dns $vms[($batch + $index)].dns1,$vms[($batch + $index)].dns2 | Out-Null
											}
											
                                            #we need to keep track of these cloned OSCustomizationSpecs for the clean-up before we exit
											$cloned_2b_cleaned += $cloned_oscust
											(Get-Date -Format ("[yyyy-MM-dd HH:mm:ss] ")) + ":Info: Starting async deployment for $($vms[($batch + $index)].name)" | out-file $log -Append
											$newvm_tasks[(new-vm -name $($vms[($batch + $index)].name) -template $(get-template -name $($vms[($batch + $index)].template)) -vmhost $vmhosts[$index] -oscustomizationspec $cloned_oscust -datastore $(get-datastorecluster -name $($vms[($batch + $index)].datastorecluster)) -location $(get-folder -name $($vms[($batch + $index)].environment)) -ResourcePool $(get-resourcepool -name $($vms[($batch + $index)].environment)) -RunAsync -ErrorAction SilentlyContinue).id] = $($vms[($batch + $index)].name)
                                            #catch new-vm errors - if any
                                            if ($error.count) {
                                                $error[0].exception | out-file $log -Append
                                                $job_progress.DPLFAIL++
                                                $error.clear()
                                            }
										}
									}
									else { 
										(Get-Date -Format ("[yyyy-MM-dd HH:mm:ss] ")) + ":Error: VM $($vms[($batch + $index)].name) already exists! Skipping" | out-file $log -Append
									}
									$index++
								}
								else {
									$index = $total_hosts #end of array, no point in looping.
								}
							}
							
                            #track the progress of async tasks
							$running_tasks = $newvm_tasks.count
							#exit #debug
							while($running_tasks -gt 0){
									$Error.clear()
									get-task | %{
										if ($newvm_tasks.ContainsKey($_.id)){ #check if deployment of this VM has been initiated above
										
											if($_.State -eq "Success"){ #if deployment successful - power on!

                                                (Get-Date -Format ("[yyyy-MM-dd HH:mm:ss] ")) + ":Info: $($newvm_tasks[$_.id]) deployed! Configuring" | out-file $log -Append
												$started_vm = "$($newvm_tasks[$_.id])"
                                                $started_vm_id = $vms | where {$_.name -eq $started_vm}    
                                                 
                                                #Configure notes,memory,cpu
                                                (Get-Date -Format ("[yyyy-MM-dd HH:mm:ss] ")) + ":Info: VM $($started_vm_id.name) configuring CPU, Memory" | out-file $log -Append
                                                Set-VM -VM $started_vm_id.Name -Notes $started_vm_id.notes -Confirm:$false -MemoryGB $started_vm_id.RAM -NumCpu $started_vm_id.CPU -ErrorAction SilentlyContinue | Out-Null
    
                                                #Configure Disk size
                                                (Get-Date -Format ("[yyyy-MM-dd HH:mm:ss] ")) + ":Info: VM $($started_vm_id.name) configuring Disk" | out-file $log -Append
                                                Get-VM $started_vm_id.Name | Get-HardDisk | Where-Object {$_.Name -eq "Hard Disk 1"} | Set-HardDisk -CapacityGB $started_vm_id.DISK1 -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
                                                #Add second disk (D) if configured
                                                if ($started_vm_id.Diskd -NotMatch "none")
                                                {    
                                                    Get-VM $started_vm_id.Name | New-HardDisk -CapacityGB $started_vm_id.DISKD -storageformat Thin -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
                                                }

                                              
                                                #Add third disk (Y) if configured
                                                if ($started_vm_id.Disky -NotMatch "none")
                                                {    
                                                    Get-VM $started_vm_id.Name | New-HardDisk -CapacityGB $started_vm_id.DISKY -storageformat Thin -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
                                                }

                                                #Add fourth disk (e) if configured
                                                if ($started_vm_id.Diske -NotMatch "none")
                                                {    
                                                    Get-VM $started_vm_id.Name | New-HardDisk -CapacityGB $started_vm_id.DISKE -storageformat Thin -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
                                                }

                                                 #Configure VLAN/Network
                                                (Get-Date -Format ("[yyyy-MM-dd HH:mm:ss] ")) + ":Info: VM $($started_vm_id.name) configuring Network" | out-file $log -Append
                                                $na = Get-VM $started_vm_id.Name | Get-NetworkAdapter | Where-Object {$_.Name -eq "Network adapter 1"}
                                                (Get-Date -Format ("[yyyy-MM-dd HH:mm:ss] ")) + ":Info: VLAN $($started_vm_id.VLAN)" | out-file $log -Append
                                                Set-NetworkAdapter -NetworkAdapter $na -Portgroup $started_vm_id.VLAN -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
                                                Set-NetworkAdapter -NetworkAdapter $na -StartConnected:$true -Confirm:$false -ErrorAction SilentlyContinue | Out-Null

                                                     
                                                (Get-Date -Format ("[yyyy-MM-dd HH:mm:ss] ")) + ":Info: $($started_vm_id.name) configured! Powering on" | out-file $log -Append
                                              
                                                #Start-VM $started_vm_id.name -confirm:$false -ErrorAction SilentlyContinue | Out-Null
                                                $started_vms += (Get-VM -name $newvm_tasks[$_.id]) | Start-VM -confirm:$false -ErrorAction SilentlyContinue
                                                
                                              
                                                
                                                #if ($error.count) { $job_progress.PWRFAIL++ }
												#else {$job_progress.PWROK++}
                                                $job_progress.PWROK++
												$newvm_tasks.Remove($_.id) #and remove task from hash table 
												$running_tasks--
											}
											elseif($_.State -eq "Error"){ #if deployment failed - only report it and remove task from hash table
												(Get-Date -Format ("[yyyy-MM-dd HH:mm:ss] ")) + ":Error: $($newvm_tasks[$_.id]) NOT deployed! Skipping" | out-file $log -Append
												$newvm_tasks.Remove($_.id)
												$job_progress.PWRFAIL++
												$running_tasks--
											}
										}
																			
									}
								#and write it down for parent process to display
                                $job_progress | Export-Csv -Path $progress -NoTypeInformation
								Start-Sleep -Seconds 5	
								}	
							$batch += $total_hosts #skip to next batch
					}
					
					Start-Sleep -Seconds 5
					
					#this is where real rock'n'roll starts, searching for customization events
					
					#there is a chance, not all vms power-on successfully
					$started_vms = $started_vms | where-object { $_.PowerState -eq "PoweredOn"}
					
					#but if they are
					if ($started_vms){
						#first - initialize helper objects to track customization, we assume customization has not started for any of successfully powered-on vms
						#exit #debug
						$vm_descriptors = New-Object System.Collections.ArrayList
						foreach ($vm in $started_vms){
								$obj = "" | select VM,CustomizationStatus,StartVMEvent 
								$obj.VM = $vm
								$obj.CustomizationStatus = "CustomizationNotStarted"
								$obj.StartVMEvent = Get-VIEvent -Entity $vm -Start $start_events | where { $_ -is "VMware.Vim.VmStartingEvent" } | Sort-object CreatedTime | Select -Last 1 
								[void]($vm_descriptors.Add($obj))
						}
					
						#timeout from here
						$start_timeout = get-date
						#now that's real mayhem - scriptblock inside scriptblock
						$continue = {
								#we check if there are any VMs left with customization in progress and if we didn't run out of time
								$vms_in_progress = $vm_descriptors | where-object { $Customization_In_Progress -contains $_.CustomizationStatus }
								$now = get-date
								$elapsed = $now - $start_timeout
								$no_timeout = ($elapsed.TotalSeconds -lt $timeout_sec)
								if (!($no_timeout) ){
									(Get-Date -Format ("[yyyy-MM-dd HH:mm:ss] ")) + ":Error: Timeout waiting for customization! Manual cleanup required! Exiting..." | out-file $log -Append
								}
								return ( ($vms_in_progress -ne $null) -and ($no_timeout)) #return $true or $false to control "while loop" below
						}
					
						#loop searching for events
						while (& $continue){
								foreach ($vmItem in $vm_descriptors){
									$vmName = $vmItem.VM.name
									switch ($vmItem.CustomizationStatus) {
								    
                                    #for every VM filter "Customization Started" events from the moment it was last powered-on
										"CustomizationNotStarted" {
											$vmEvents = Get-VIEvent -Entity $vmItem.VM -Start $vmItem.StartVMEvent.CreatedTime 
											$startEvent = $vmEvents | where { $_ -is "VMware.Vim.CustomizationStartedEvent"} 
											if ($startEvent) { 
												$vmItem.CustomizationStatus = "CustomizationStarted" 
												$job_progress.CUSTSTART++
												(Get-Date -Format ("[yyyy-MM-dd HH:mm:ss] ")) + ":Info: OS Customization for $vmName started at $($startEvent.CreatedTime)" | out-file $log -Append
											}
									
										break;} 
								
										#pretty much same here, just searching for customization success / failure)
										"CustomizationStarted" {
											$vmEvents = Get-VIEvent -Entity $vmItem.VM -Start $vmItem.StartVMEvent.CreatedTime 
											$succeedEvent = $vmEvents | where { $_ -is "VMware.Vim.CustomizationSucceeded" } 
											$failedEvent = $vmEvents | where { $_ -is "VMware.Vim.CustomizationFailed"} 
											if ($succeedEvent) { 
												$vmItem.CustomizationStatus = "CustomizationSucceeded"
												$job_progress.CUSTOK++
												(Get-Date -Format ("[yyyy-MM-dd HH:mm:ss] ")) + ":Info: OS Customization for $vmName completed at $($succeedEvent.CreatedTime)" | out-file $log -Append
											} 
											if ($failedEvent) { 
												$vmItem.CustomizationStatus = "CustomizationFailed" 
												$job_progress.CUSTFAIL++
												(Get-Date -Format ("[yyyy-MM-dd HH:mm:ss] ")) + ":Error: OS Customization for $vmName failed at $($failedEvent.CreatedTime)" | out-file $log -Append 
											} 
									
										break;} 
								
									}
								}
							$job_progress | Export-Csv -Path $progress -NoTypeInformation
							Start-Sleep -Seconds 10	
						}
					}
                    #we've got no loose ends at the moment (well, except for timeouts but... tough luck)
					(Get-Date -Format ("[yyyy-MM-dd HH:mm:ss] ")) + ":Info: Cleaning-up cloned OS customizations" | out-file $log -Append
					$cloned_2b_cleaned | Remove-OSCustomizationSpec -Confirm:$false
					
				}
				else{
					(Get-Date -Format ("[yyyy-MM-dd HH:mm:ss] ")) + ":Error: vCenter $vCS connection failure" | out-file $log -Append
				}
						
}
###################################
#End of Script Block that Builds VMs
###################################