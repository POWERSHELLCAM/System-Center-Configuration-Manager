
# ######################################################################
#
# 	Program         :   EXPORT_SCCM_APPLICATION_INFORMATION.ps1
# 	Version         :   1.1
# 	Purpose         :   Get the application INFORMATION from list of application name.
# 	Author          :	Shishir Kushawaha
#	Mail Id         :   srktcet@gmail.com
#   Created         :   09/06/2020 - Script creation.
# 	Modified        :	
# ######################################################################

<# Objective:
	To get application information from list of application name.
#>

<# How to execute:
	Prepare list of application in app_export_list.txt file which should be stored in the same path where script stored.
	Ensure you have SCCM management point reachable and have access. 
	Directly run the script with Administrative previlage.
#>

<# Execution:
	Script will connect to SCCM and perform the retreival of application information in .HTML file.
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
 clear-host
 $location=get-location 
 $InputColor="yellow" 
 $ProcessColor="write-host `$ProcessMessage -ForegroundColor gray -BackgroundColor darkgreen" 
 $pkg_input_list="$location\app_export_list.txt"
 $packagelist=get-content $pkg_input_list -erroraction silentlycontinue
 

if(test-path  $pkg_input_list -erroraction silentlycontinue)
{
	if($packagelist)
	{
		InitializeSCCM
		foreach($app_name in $packagelist)
		{
			$pkg_info=Get-CMApplication -name $app_name
			if($pkg_info)
			{
				write-host ""
				write-host "$app_name exist in SCCM." -foregroundcolor green
				if($app_name.split('\')[1] -or $app_name.split('/')[1])
				{$ReportTitle="Application $($pkg_info.PackageId) Details"}
				else
				{$ReportTitle="Application $($pkg_info.PackageId)- $app_name Details"}
				
				$strPath = "$location\$ReportTitle.html" 
				if(test-path $strpath -ea silentlycontinue){remove-item $strpath -force}
				$app_SDM=$pkg_info | select SDMPackageXML
				$pkg_info | select LocalizedDisplayName,PackageId,LocalizedDescription,SoftwareVersion,NumberOfDeployments,NumberOfDeploymentTypes,Manufacturer,CreatedBy,DateCreated,DateLastModified,CI_ID,CI_UniqueID,IsSuperseded,IsSuperseding | ConvertTo-html  -Head $test -Body "<h2>Application $app_name General Information</h2>" >> "$strPath"
				
				$AppMgmt = ([xml]$app_SDM.SDMPackageXML).AppMgmtDigest				
				
				
				$app_other_info=[pscustomobject]@{
				'Data Source Path'=$AppMgmt.DeploymentType.Installer.Contents.Content.Location
				'Install CommandLine'=$AppMgmt.deploymenttype.installer.CustomData.InstallCommandLine
				'UnInstall CommandLine'=$AppMgmt.deploymenttype.installer.CustomData.UnInstallCommandLine
				}
				
				$app_other_info | ConvertTo-html  -Head $test -Body "<h2>Application $app_name ComandLine Information</h2>" >> "$strPath"
			
				if($AppMgmt.DeploymentType.Installer.CustomData.EnhancedDetectionMethod.settings.File.Path)
				{
					$app_file_detection=[pscustomobject]@{
					'Detection Method'="File"
					'File Path'=$AppMgmt.DeploymentType.Installer.CustomData.EnhancedDetectionMethod.settings.File.path+"\"+$AppMgmt.DeploymentType.Installer.CustomData.EnhancedDetectionMethod.settings.File.filter
					'Operator'=$AppMgmt.DeploymentType.Installer.CustomData.EnhancedDetectionMethod.rule.Expression.Operator
					'Value'=$AppMgmt.DeploymentType.Installer.CustomData.EnhancedDetectionMethod.rule.Expression.Operands.ConstantValue.value
					}
					$app_file_detection | ConvertTo-html  -Head $test -Body "<h2>Application $app_name Detection Method Information</h2>" >> "$strPath"
				}
				
				if($AppMgmt.DeploymentType.Installer.CustomData.EnhancedDetectionMethod.settings.MSI.ProductCode)
				{
					$app_MSI_detection=[pscustomobject]@{
					'Detection Method'="Windows Installer"
					'MSI Product'=$AppMgmt.DeploymentType.Installer.CustomData.EnhancedDetectionMethod.settings.MSI.ProductCode
					'MSI Property'=$AppMgmt.DeploymentType.Installer.CustomData.EnhancedDetectionMethod.rule.Expression.Operands.ConstantValue.datatype
					'Operator'=$AppMgmt.DeploymentType.Installer.CustomData.EnhancedDetectionMethod.rule.Expression.Operator
					'Value'=$AppMgmt.DeploymentType.Installer.CustomData.EnhancedDetectionMethod.rule.Expression.Operands.ConstantValue.value
					}
					$app_MSI_detection | ConvertTo-html  -Head $test -Body "<h2>Application $app_name Detection Method Information</h2>" >> "$strPath"
				}
				
				if($AppMgmt.DeploymentType.Installer.CustomData.EnhancedDetectionMethod.settings.SimpleSetting.RegistryDiscoverySource.Key)
				{
					$app_REG_detection=[pscustomobject]@{
					'Detection Method'="Registry"
					'Registry Path'=$AppMgmt.DeploymentType.Installer.CustomData.EnhancedDetectionMethod.settings.SimpleSetting.RegistryDiscoverySource.Key
					'Registry Key'=$AppMgmt.DeploymentType.Installer.CustomData.EnhancedDetectionMethod.settings.SimpleSetting.RegistryDiscoverySource.ValueName
					'Operator'=$AppMgmt.DeploymentType.Installer.CustomData.EnhancedDetectionMethod.rule.Expression.Operator
					'Registry Value'=$AppMgmt.DeploymentType.Installer.CustomData.EnhancedDetectionMethod.rule.Expression.Operands.ConstantValue.value
					}
					$app_REG_detection | ConvertTo-html  -Head $test -Body "<h2>Application $app_name Detection Method Information</h2>" >> "$strPath"
				}
				
				$app_deployment=Get-CMApplicationDeployment -name $app_name
				if($app_deployment)
				{
					$app_deployment | select AssignmentID,AssignmentName,TargetCollectionID,CollectionName,CreationTime,StartTime | ConvertTo-html  -Head $test -Body "<h2>Application $app_name Deployment Information</h2>" >> "$strPath"
				}
				write-host "$app_name information exported at $strpath." -foregroundcolor cyan
			}
			else
			{
				write-host "$app_name does not exist in SCCM." -foregroundcolor red
				
			}
			$pkg_info=$app_name=$reporttitle=$app_deployment=$app_REG_detection=$app_MSI_detection=$app_File_detection=$null
		}
		deinitializeSCCM 
	}
	else
	{
		write-host "List of packages are not specified under $collectionlist." -foregroundcolor red
	}
}
else
{
 write-host "$pkg_input_list does not exist" -foregroundcolor red
}



