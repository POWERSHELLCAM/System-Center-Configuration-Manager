
function InitializeSCCM 
{ 
    $ProcessMessage="`n Please wait.Initializing SCCM ........." 
    
    # Site configuration
    do
    { 
        write-host "`n Enter Site Code : " -foregroundcolor $inputcolor -nonewline 
        $SiteCode = read-host 
        $siteResult=($siteCode -match '\b^[a-zA-Z0-9]{3}\b')
        if(!$siteResult)
        {
        write-host " Site code can have only [3] alphanumeric characters. Please re-enter site code" -foregroundcolor RED
        }
    }while(!$siteResult)

    do
    {
        write-host "`n Enter SMS Provider Server Name : " -foregroundcolor $inputcolor -nonewline 
        $ProviderMachineName = read-host 
        $nameResult=($ProviderMachineName -match '\b^(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)*([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9\-]*[A-Za-z0-9])$\b')
        if(!$nameResult)
        {
        write-host " Entered SMS provider name is not valid as per naming conventions. Please re-enter provider name" -foregroundcolor RED
        }
    }while(!$nameResult)

    Invoke-Expression $ProcessColor 
    Start-Sleep 2 
    # Customizations 
    $initParams = @{} 
    
    # Import the ConfigurationManager.psd1 module  
    if($null -eq (Get-Module ConfigurationManager)) 
    { 
        Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1" @initParams  
    } 
    
    # Connect to the site's drive if it is not already present 
    if($null -eq (Get-PSDrive -Name $SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue)) 
    { 
        New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $ProviderMachineName @initParams 
    } 
    
    # Set the current location to be the site code. 
    Set-Location "$($SiteCode):\" @initParams 
} 
 
function deinitializeSCCM 
{
    #De-initialize SCCM
	$ProcessMessage="`n Please wait.De-Initializing SCCM ......" 
	Invoke-Expression $ProcessColor 
	Start-Sleep 2 
	set-location $location 
} 

$BackupPath = ""
if($BackupPath -ne "")
{
    $Timestamp = Get-Date -Format "dd-MM-yyyy"
    $BackupFolder=Join-Path $BackupPath "\$timestamp"
    if(!(Test-Path $BackupFolder -ErrorAction SilentlyContinue))
    {
        # Create backup directory if it doesn't exist
        New-Item -ItemType Directory -Force -Path $BackupFolder
    }
    else 
    {
        "Directory $backupfolder already exists."
    }

    #Use this variable to filter the task sequence based on name.
    $namefilter=""
    InitializeSCCM
    # List all task sequences
    if($filter -ne "")
    {
        $AllTaskSequences=Get-CMTaskSequence -Fast | Where-Object { $_.name -match $namefilter} | Select-Object name,packageid
    }
    else 
    {
        $AllTaskSequences=Get-CMTaskSequence -Fast | Select-Object name,packageid
    }
    # Export the task sequences to location mentioned
    $AllTaskSequences | ForEach-Object { 
        "Exporting Task Sequence $($_.name)-$($_.packageid)"
        Export-CMTaskSequence -TaskSequencePackageId $_.packageid -ExportFilePath "$BackupFolder\$($_.packageid)-$($_.name).zip" -WithContent $false -WithDependence $false
    }
    deinitializeSCCM
}
else 
{
    "Backup path is missing. Please define the backup path and run the script again."
}
