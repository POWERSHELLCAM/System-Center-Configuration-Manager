
# ######################################################################
#
# 	Program         :   TASK_SEQUENCE_DETAILS.ps1
# 	Version         :   1.1
# 	Purpose         :   Get task sequence information
# 	Author          :	Shishir Kushawaha
#   Mail Id         :   srktcet@gmail.com
#   Created         :   05-10-2018 - Script creation.
# 	Modified        :	26-09-2021
#						Added comments
#						Some bug correction
#						Suppot for Task sequence group
#                       Added information for Driver Packages
# ######################################################################

<# Objective:
	The purpose of the script to list important information of a task sequence like package , OS/Boot Image,Driver Packages etc. This will help in to understand the 
	task sequence in detail without going over task sequence and exploring each step.
#>

<# How to execute:
	Ensure you have SCCM management point reachable and have access. 
	Directly run the script with Administrative previlage.
#>

<# Execution:
  This script will accept the task sequence package ID information from the prompt. Once entered , It will retrieve the following information from the SCCM

	OS Image
	Boot Image
	Drivers Integrated in boot image
	Optional Component added to boot image
	Task Sequence
	Run Commandline Used
	Driver Package
	Application List
	Package List
	Network Settings
	Task Sequence group
	Script will generate the .HTML page which will have all information in tabular format.

	There is a variable which is specify the .HTML store location as $Location. It can be modified as per the requirement.
#>
function InitializeSCCM 
{ 
	$ProcessMessage="`n Please wait.Initializing SCCM ......" 
	
	# Site configuration 
	write-host "`n Enter Site Code : " -foregroundcolor $inputcolor -nonewline 
	$SiteCode = read-host 
	write-host "`n Enter SMS Provider Server Name : " -foregroundcolor $inputcolor -nonewline 
	$ProviderMachineName = read-host  
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
function updateHTML
{
	param ($strPath)
	IF(Test-Path $strPath)
	{ 
		Remove-Item $strPath
	}
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

 #--Variable declaration
 Clear-Host
 $location=get-location 
 $InputColor="magenta" 
 $ProcessColor="write-host `$ProcessMessage -ForegroundColor gray -BackgroundColor darkgreen" 
 InitializeSCCM 

do
{
	#Initialize task sequence
	write-host "`n Enter task sequence packageID : " -foregroundcolor $inputcolor -nonewline 
 	$taskSequencePackageID=read-host  
 	$ReportTitle="Task Sequence $taskSequencePackageID Details"
	$strPath = "$location\$ReportTitle.html" 
	updateHTML $strPath
	write-host "`n Processing all packages which are integrated in $taskSequencePackageID.Please wait for 2-3 min" -ForegroundColor gray -BackgroundColor darkgreen 

	#Task Sequence Information
	$taskSequenceResult=Get-CMTaskSequence -TaskSequencePackageId $taskSequencePackageID
	if($null -ne $taskSequenceResult)
	{
		ConvertTo-Html -Head $test -Title $ReportTitle -Body "<h1> Windows $ReportTitle </h1>" >  "$strPath" 
		$taskSequenceResult |Select-Object Name,BootImageID,Description,PackageId,LastRefreshTime,Sourcedate | ConvertTo-html  -Head $test -Body "<h2>Task Sequence $taskSequencePackageID Information</h2>" >> "$strPath"

		#OS Image and Apply Operating System Step Information
		$stepOperatingSystem=Get-CMTaskSequenceStepApplyOperatingSystem -TaskSequenceId $taskSequencePackageID
		$operatingSystemPackageID=$stepOperatingSystem.ImagePackageID
		if($null -ne $operatingSystemPackageID)
		{
			Get-cmoperatingsystemimage -id $operatingSystemPackageID | Select-Object Name,Description, ImageosVersion,Lastrefreshtime,PackageID, PackageSize,PkgsourcePath,SourceDate,version |  ConvertTo-html  -Head $test -Body "<h2>Operating System Image Information</h2>" >> "$strPath"
			$stepOperatingSystem| Select-Object Name,ImagePackageID,ImageIndex,DestinationVariable,DestinationDisk,DestinationLogicalDrive,DestinationPartition,ConfigFileName,ConfigFilePackage |  ConvertTo-html  -Head $test -Body "<h2>Operating System Step Information</h2>" >> "$strPath"
		}

		#Upgrade Operating System Information
		$operatingSystemUpgradePackageResult=Get-CMTaskSequenceStepUpgradeOperatingSystem -TaskSequenceId $taskSequencePackageID | Select-Object Name,Description,DriverPackageID,InstallPackageID,InstallPath,OSProductKey,StagedContent
		if($null -ne $operatingSystemUpgradePackageResult)
		{
			$operatingSystemUpgradePackageResult |  ConvertTo-html  -Head $test -Body "<h2>Ugrade Operating System Step Information</h2>" >> "$strPath"
		}

		#BootImage Information
		try
		{
			$bootImagePackageID=$taskSequenceResult.bootimageid
		}
		catch{}
		if(($null -ne $bootImagePackageID) -or ($bootImagePackageID -ne ' '))
		{
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
							$driverResult=Get-CMDriver -id $id -fast|Select-Object LocalizedDisplayName,DriverVersion,CI_ID
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

		$TSDownloadPackageContentResult=Get-CMTaskSequenceStepDownloadPackageContent -TaskSequenceId $taskSequencePackageID | Select-Object -ExpandProperty PackageInfo | Select-Object Name,PackageID,Size,Count,Properties
		if($null -ne $TSDownloadPackageContentResult)
		{
			$TSDownloadPackageContentResult | ConvertTo-html  -Head $test -Body "<h2>Download Package Content </h2>" >> "$strPath"
					
		}
		
		#Task Sequence Package and Application Information
		$taskSequencePackages=$taskSequenceResult.references.package
		$taskSequencePackageResult=New-Object System.Collections.ArrayList
		$taskSequenceApplicationResult=New-Object System.Collections.ArrayList
		$taskSequenceDriverPackageResult=New-Object System.Collections.ArrayList
		foreach($tPid in $taskSequencePackages)
			{
				$app_info=$ApplicationResult=$null
				$packageResult=Get-CMPackage -id  $tPid -fast | Select-Object Name , PackageID,@{'Name'='Package Type';Expression= {'Software Package'}},Version,PkgSourcePath
				$driverPackageResult=Get-CMDriverPackage -id  $tPid -fast | Select-Object Name , PackageID,@{'Name'='Package Type';Expression= {'Driver Package'}},Version,PkgSourcePath
				
				$ApplicationResult=Get-CMApplication -modelname  $tPid | Select-Object LocalizedDisplayName,PackageID,@{'Name'='Package Type';Expression= {'Software Application'}},SoftwareVersion
				$app_SDM=Get-CMApplication -modelname  $tPid | Select-Object SDMPackageXML
				$AppMgmt = ([xml]$app_SDM.SDMPackageXML).AppMgmtDigest				
				$applocation=$AppMgmt.DeploymentType.Installer.Contents.Content.Location
				if($null -ne $ApplicationResult)
				{
					$app_info=[pscustomobject]@{
					'Name'=$($ApplicationResult.LocalizedDisplayName)
					'Package ID'=$($ApplicationResult.PackageID)
					'Package Type'='Software Applications'
					'Version'=$($ApplicationResult.SoftwareVersion)
					'Data Source Path'=$applocation
					}
					[void]$taskSequenceApplicationResult.add($app_info)
				}
				[void]$taskSequencePackageResult.add($packageResult)
				[void]$taskSequenceDriverPackageResult.add($driverPackageResult)
			}

		#Software Packages Information
		if($null -ne $taskSequencePackageResult)
		{
			$taskSequencePackageResult | ConvertTo-html  -Head $test -Body "<h2>Integrated Packages </h2>" >> "$strPath"
		}
		
		#Driver Packages Information
		if($null -ne $taskSequenceDriverPackageResult)
		{
			$taskSequenceDriverPackageResult | ConvertTo-html  -Head $test -Body "<h2> Driver Packages </h2>" >> "$strPath"
		}

		#Application Information
		if($null -ne $taskSequenceApplicationResult)
		{
			$taskSequenceApplicationResult | ConvertTo-html  -Head $test -Body "<h2>Integrated Applications </h2>" >> "$strPath"
		}

		#Task Sequence Driver Package Information
		$listTSDriverPackageResult=Get-CMTaskSequenceStepApplyDriverPackage -TaskSequenceId $taskSequencePackageID | Select-Object Name,DriverPackageID,Enabled,Description,UnsignedDriver
		if($null -ne $listTSDriverPackageResult)
		{
			$listTSDriverPackageResult | ConvertTo-html  -Head $test -Body "<h2>Driver Package Integrated</h2>" >> "$strPath"
		}

		#Task Sequence Run CommandLine Information
		$listTSRuncommandLineResult=Get-CMTaskSequenceStepRunCommandLine -TaskSequenceId $taskSequencePackageID 
		if($null -ne $listTSRuncommandLineResult)
		{
			$listTSRuncommandLineResult | Select-Object Name,PackageID,Commandline,Description,ContinueOnError | ConvertTo-html  -Head $test -Body "<h2>CommandLine Added</h2>" >> "$strPath"
		}

		#Tas Sequence Network Setting Information
		$listTSNetworkSettingResult=Get-CMTaskSequenceStepApplyNetworkSetting -TaskSequenceId $taskSequencePackageID
		if($null -ne $listTSNetworkSettingResult)
		{
			$listTSNetworkSettingResult | Select-Object Name,DomainName,DomainOUName | ConvertTo-html  -Head $test -Body "<h2> Network Settings </h2>" >> "$strPath"
		} 

		#Task Sequence group
		$listTsGroupResult=Get-CMTaskSequenceGroup -TaskSequenceId $taskSequencePackageID | Select-Object Name,Description,Condition,Enabled 
		if($null -ne $listTsGroupResult)
		{
			$listTsGroupResult | ConvertTo-html  -Head $test -Body "<h2> Task Sequence Group</h2>" >> "$strPath"
		}

		#Launching HTML generated report 
		write-host "`n Openning $strpath report : " -foregroundcolor $inputcolor -nonewline 
		Invoke-Item $strPath 
	}
	else 
	{
		Write-Host "`n  Not a Valid Task Seuqnce PackageID." -ForegroundColor Red
	}
	do
		{
			$retryInput=Read-Host -Prompt "`n Do you want to retry and check for other Task Sequence Package?[Yes / NO]"
			if($retryInput -match 'no')
			{
				$retryAgain=$false
			}
			if($retryInput -match 'yes')
			{
				$retryAgain=$true
			}	
			if($retryInput -notin @('yes','no'))
			{
				write-host "`n Enter proper choice"
			}
		}while($retryInput -notin @('yes','no'))
		if(!$retryAgain)
		{
			#De-initializing SCCM 
			deinitializeSCCM 
		}
		get-variable -Name '*result*' | Remove-Variable
}while ($retryAgain) 
