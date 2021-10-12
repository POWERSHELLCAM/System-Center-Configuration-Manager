function InitializeSCCM 
{ 
    $ProcessMessage="`n Please wait.Initializing SCCM ......" 
    
    # Site configuration 
    write-host "`n Enter Site Code : " -foregroundcolor $inputcolor -nonewline 
    $SiteCode = read-host 
    write-host "`n Enter SMS Provider Server Name : " -foregroundcolor $inputcolor -nonewline 
    $ProviderMachineName = read-host  
    iex $ProcessColor 
    sleep 2 
    # Customizations 
    $initParams = @{} 
    
    # Import the ConfigurationManager.psd1 module  
    if((Get-Module ConfigurationManager) -eq $null) { 
        Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1" @initParams  
    } 
    
    # Connect to the site's drive if it is not already present 
    if((Get-PSDrive -Name $SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue) -eq $null) { 
        New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $ProviderMachineName @initParams 
    } 
    
    # Set the current location to be the site code. 
    Set-Location "$($SiteCode):\" @initParams 
} 
 
function deinitializeSCCM 
{ 
    $ProcessMessage="`n Please wait.De-Initializing SCCM ......" 
    iex $ProcessColor 
    sleep 2 
    set-location $location 
} 


 #--Variable declaration
 clear
 $location=get-location 
 $InputColor="magenta" 
 $ProcessColor="write-host `$ProcessMessage -ForegroundColor gray -BackgroundColor darkgreen" 
 InitializeSCCM 
 
 write-host "`n Enter name of DrivePackage : " -foregroundcolor $inputcolor -nonewline 
 $driverPackageName=read-host
 write-host "`n Enter DrivePackage source path: " -foregroundcolor $inputcolor -nonewline 
 $driverPackageSourcePath=read-host

 write-host "`n Enter path of Text file having list of CI ID : " -foregroundcolor $inputcolor -nonewline 
 $driverFileNamePath=read-host
 $CIIDList=get-content $driverFileNamePath
 
 if(test-path $driverPackageSourcePath)
 {
    #Create Driver Package
    $driverpackageCreated=New-CMDriverPackage -Name $driverPackageName -Path $driverPackageSourcePath

    #Add drivers in driver package created above
    foreach($ciid in $CIIDList)
    {
        Add-CMDriverToDriverPackage -driverid $ciid -DriverPackageID $driverpackageCreated.packageid
    }
    write-host " Driver package created. Please find the details." -foregroundcolor green
    get-CMDriverPackage -packageid $($driverpackageCreated.packageid)
 }
 else
 {
	write-host " Driver package path does not exist or invalid"
 }
 

#De-initializing SCCM 
deinitializeSCCM 