$LUN = Read-Host "Enter LUN name"
$CG = Read-Host "Enter Consistency Group #"
$group = 'CG',$cg,'_',$LUN -join ""
$copy1 = 'CG',$cg,'_',$LUN,'_Neenah' -join ""
$copy2 = 'CG',$cg,'_',$LUN,'_DR' -join ""


write-host config_link_policy group=$group copy_1=$copy1 copy_2=$copy2 bandwidth_limit=100
