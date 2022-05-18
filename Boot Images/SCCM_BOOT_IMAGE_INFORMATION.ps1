
# ######################################################################
#
# 	Program         :   SCCM_BOOT_IMAGE_INFORMATION.ps1
# 	Version         :   1.1
# 	Purpose         :   Get the details of boot images
# 	Author          :	Shishir Kushawaha
#	Mail Id         :  srktcet@gmail.com
#   	Created         :   07/10/2019 - Script creation.
# 	Modified        :	15-10-2019
#						Added comments
#						Some bug correction
# ######################################################################


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



#--CSS formatting
$test=@'
<style type="text/css">
 h1, h5,h2, th { text-align: left; font-family: Segoe UI;font-size: 13px;}
table { margin: left; font-family: Segoe UI; box-shadow: 10px 10px 5px #888; border: thin ridge grey; }
th { background: #0046c3; color: #fff; max-width: 400px; padding: 5px 10px; font-size: 12px;}
td { font-size: 11px; padding: 5px 20px; color: #000; }
tr { background: #b8d1f3; }
tr:nth-child(even) { background: #dae5f4; }
tr:nth-child(odd) { background: #b8d1f3; }
</style>
'@
$bootimagelist=gc C:\temp\bootimagelist.txt


InitializeSCCM

#BootImage Information
foreach($bootImagePackageID in $bootimagelist)
{
		
		if(($null -ne $bootImagePackageID) -or ($bootImagePackageID -ne ' '))
		{
            $ReportTitle="Boot Image $bootImagePackageID Details"
	        $strPath = "c:\temp\boot_image_details\$ReportTitle.html" 

			$bootImageResult=Get-CMBootImage -id $bootImagePackageID
			$bootImageResult|Select-Object Name,PackageId,SourceDate,ScratchSpace,PkgSourcePath,PreExecCommandLine,PreExecSourceDirectory,PackageSize,ImageIndex,ImagePath,ImageOSVersion | ConvertTo-html  -Head $test -Body "<h2>Boot Image $bootImagePackageID Information</h2>" >> "$strPath"
            
            
			#BootImage Driver Information
			if($null -ne $bootImageResult)
			{
				$bootImageReferenceDriversCIID=$bootImageResult.ReferencedDrivers.id
				if($null -ne $bootImageReferenceDriversCIID)
				{
					$bootImageReferenceDriverResult=New-Object System.Collections.ArrayList
					foreach($id in $bootImageReferenceDriversCIID)
						{
							$driverResult=Get-CMDriver -id $id |Select-Object LocalizedDisplayName,DriverVersion,CI_ID,ContentSourcePath,DateCreated,DriverClass,DriverDate,DriverINFFile,ObjectPath
							[void]$bootImageReferenceDriverResult.add($driverResult)
						}
					if($null -ne $bootImageReferenceDriverResult)
					{
						$bootImageReferenceDriverResult | ConvertTo-html  -Head $test -Body "<h2>Drivers injected in Boot Image $bootImagePackageID </h2>" >> "$strPath"
				
					}
				}

				#BootImage Optional Component Information
				$bootImageOptionalComponent=$bootImageResult.optionalcomponents
				if($null -ne $bootImageReferenceDriversCIID)
				{
					$bootImageOptionalComponentResult=New-Object System.Collections.ArrayList
					foreach($Cid in $bootImageOptionalComponent)
						{
							$componentResult=Get-CMWinPEOptionalComponentInfo -UniqueId $cid | Select-Object Name,@{Expression={$_.DependentComponentNames -as [string]};Label="Dependent Component"}-unique
							[void]$bootImageOptionalComponentResult.add($componentResult)
						}
					if($null -ne $bootImageOptionalComponentResult)
					{
						$bootImageOptionalComponentResult | ConvertTo-html  -Head $test -Body "<h2>Installed Optional Component in Boot Image $bootImagePackageID </h2>" >> "$strPath"
					}
				}
			}
		}
$bootImagePackageID=$ReportTitle=$strPath=$bootImageReferenceDriverResult=$bootImageReferenceDriversCIID=$bootImageOptionalComponent=$bootImageOptionalComponentResult=$null
}

deinitializeSCCM
