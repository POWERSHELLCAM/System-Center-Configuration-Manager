
# ######################################################################
#
# 	Program         :   EXPORT_SCCM_PACKAGE_INFORMATION.ps1
# 	Version         :   1.1
# 	Purpose         :   Get the PACKAGE INFORMATION from list of package ID.
# 	Author          :	Shishir Kushawaha
#	Mail Id         :   srktcet@gmail.com
#   Created         :   09/06/2020 - Script creation.
# 	Modified        :	
# ######################################################################

<# Objective:
	To get package information from list of package ID.
#>

<# How to execute:
	Prepare list of packages in package_export_list.txt file which should be stored in the same path where script stored.
	Ensure you have SCCM management point reachable and have access. 
	Directly run the script with Administrative previlage.
#>

<# Execution:
	Script will connect to SCCM and perform the retreival of package information in .HTML file.
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
 $pkg_input_list="$location\package_export_list.txt"
 $packagelist=get-content $pkg_input_list -erroraction silentlycontinue
 

if(test-path  $pkg_input_list -erroraction silentlycontinue)
{
	if($packagelist)
	{
		InitializeSCCM
		foreach($packageid in $packagelist)
		{
			$pkg_info=Get-cmpackage -id $packageid -fast |select Name,Description,Manufacturer,NumOfPrograms,ObjectPath,PackageID,PackageType,PackageSize,PkgSourcePath,SourceDate
			if($pkg_info)
			{
				write-host "$packageid does exist in SCCM." -foregroundcolor green
				$ReportTitle="Package $packageid - $($pkg_info.name) Details"
				$strPath = "$location\$ReportTitle.html" 
				if(test-path $strpath -ea silentlycontinue){remove-item $strpath -force}
				$pkg_info | ConvertTo-html  -Head $test -Body "<h2>Package $packageid General Information</h2>" >> "$strPath"   
				if($null -ne $pkg_info.NumOfPrograms -or $pkg_info.NumOfPrograms -gt 0)
				{
					$pkg_program=Get-CMProgram -PackageId $packageid | select CommandLine,PackageName,ProgramName,Description,Comment,DiskSpaceReq,Duration,PackageVersion
					$pkg_program | ConvertTo-html  -Head $test -Body "<h2>Package $packageid Program Information</h2>" >> "$strPath"
				}
				$pkg_deployment=Get-CMPackageDeployment -PackageId $packageid  | select AdvertisementID,AdvertisementName,CollectionID,Comment,ProgramName,ExpirationTime
				$pkg_deployment | ConvertTo-html  -Head $test -Body "<h2>Package $packageid Deployment Information</h2>" >> "$strPath"
				write-host "$packageid information exported at $strpath." -foregroundcolor green
			}
			else
			{
				write-host "$packageid does not exist in SCCM OR it belongs to application model." -foregroundcolor red
				
			}
			$pkg_program=$pkg_deployment=$pkg_info=$packageid=$reporttitle=$null
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



