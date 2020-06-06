
# ######################################################################
#
# 	Program         :   ADD_KNOWN_SYSTEM_TO_COLLECTION.ps1
# 	Version         :   1.1
# 	Purpose         :   Get the list of collection with NO deployment. 
# 	Author          :	Shishir Kushawaha
#	Mail Id         :   srktcet@gmail.com
#   	Created         :   07/10/2019 - Script creation.
# 	Modified        :	15-10-2019
#						Added comments
#						Some bug correction
# ######################################################################

<# Objective:
	To add multiple system to collections
#>

<# How to execute:
	Prepare list of devices in "c:\temp\deviceList.txt".
	Ensure you have SCCM management point reachable and have access. 
	Directly run the script with Administrative previlage.
	Provide the collection ID information.
#>

<# Execution:
	Script will connect to SCCM and perform the additon of devies to specified collection as a direct membership.
#>

function InitializeSCCM 
{ 
	$ProcessMessage="`n Please wait.Initializing SCCM ........." 
	 
	# Site configuration. Please provide site code and sms server information
	
	if(!$SiteCode)
		{
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
		}
	if(!$ProviderMachineName)
		{
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
		}

	Invoke-Expression $ProcessColor 
	Start-Sleep 2 
	# Customizations 
	$initParams = @{} 
	 
	# Import the ConfigurationManager.psd1 module  
	if($null -eq (Get-Module ConfigurationManager)) { 
		Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1" @initParams  
	} 
	 
	# Connect to the site's drive if it is not already present 
	if($null -eq (Get-PSDrive -Name $SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue)) { 
		New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $ProviderMachineName @initParams 
	} 
	$ProviderMachineName
	$SiteCode
	# Set the current location to be the site code. 
	Set-Location "$($SiteCode):\" @initParams 
} 
 
function deinitializeSCCM 
{ 
	$ProcessMessage="`n Please wait.De-Initializing SCCM ......" 
	Invoke-Expression $ProcessColor 
	Start-Sleep 2 
	set-location $location 
} 

#--Variable declaration
 Clear-Host
 $location=get-location 
 $InputColor="yellow" 
 $ProcessColor="write-host `$ProcessMessage -ForegroundColor gray -BackgroundColor darkgreen" 
 $DEVICE_LIST = get-content "c:\temp\deviceList.txt" 
 $collectionID=Read-Host -Prompt "`n Enter collection ID"

 $collectionName=$null
 $ini_result=InitializeSCCM
 $sitecode=$ini_result[1]
 $ProviderMachineName=$ini_result[0]
 $collectionName=(Get-CMCollection -Id $collectionID).name  
 
 if($collectionName)
 {
	clear-host
	write-host "Collection name: $collectionName"
	write-host "Site Code: $sitecode"
	write-host "SMS Server : $ProviderMachineName"
	$collection_member=(Get-CMCollectionMember -CollectionId $collectionID).resourceid
	foreach($device in $DEVICE_LIST)
	{
		$resourceID=$null
		$resourceID=(Get-WmiObject -ComputerName $ProviderMachineName -Namespace root\SMS\Site_$SiteCode -Class SMS_R_System -Filter "name ='$device'").ResourceID
		if($null -eq $resourceID)
		{
			write-host "`n $device not found in SCCM" -foregroundcolor red
			$device | Out-File "c:\temp\DeviceNotFoundSCCM.txt" -Append
		}
		else 
		{
			try
			{
				
				if(($collection_member -match $resourceID) -eq $resourceID)
				{
					write-host "`n $device is already added to collection." -foregroundcolor yellow
				}
				else
				{
					Add-CMDeviceCollectionDirectMembershipRule -CollectionId $collectionID -ResourceId $resourceID
					write-host "`n $device added to collection." -foregroundcolor green
				}
			}
			catch
			{
				write-host "`n Issue occurred while adding" -foregroundcolor red
			}
		}
	}
}
else 
{
	write-host "`n Invalid collection ID or collection ID does not exist." -foregroundcolor red	
}

deinitializeSCCM


		


		
				
		

	
  
 
