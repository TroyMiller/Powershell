#Export Customers from ConnectWise
$customers = import-csv C:\temp\companypickerlist.csv

#Where to build the root of the folder structure
$path = 'C:\temp\Example\'

#Intialize Array for folders
$folders_level1 = @()
$folders_level2 = @()

#First folders under \Customer\
$folders_level1 = "Quotes", "Presentations", "Data Collection", "SOW", "Archive", "MS"

#Folders under level1
$folders_level2 = "2017", "2016", "2015"

#Function to create path
Function Create-Folder($folderpath) 
{
    If (Test-Path -Path $folderpath -PathType Container){

        Write-Host "$folderpath already exists" -ForegroundColor Red
    }
    ELSE {
        #Make Folder
        mkdir $folderpath
    }

}


Foreach ($customer in $customers) 
{

    Write-host "Creating Folders for" $customer.'Company Name'
    $newpath = $path + $customer.'Company Name'
    Create-Folder $newpath

    #Make Subfolders level 1 in Customer folder
    foreach ($folder in $folders_level1)
    {
    $subpath = $newpath + "\" + $folder
    Create-Folder $subpath

        #Make Subfolders for level 2 \Customer\Level1\Level2
        foreach ($folder2 in $folders_level2)
        {
        $sub2path = $subpath + "\" + $folder2
        Create-Folder $sub2path
        }
    }
}


