
# ######################################################################
#
# 	Program         :   EXPORT_SCCM_COLLECTION_INFORMATION.ps1
# 	Version         :   1.1
# 	Purpose         :   Get the COLLECTION INFORMATION from list of collection ID.
# 	Author          :	Shishir Kushawaha
#	Mail Id         :   srktcet@gmail.com
#   Created         :   06/06/2020 - Script creation.
# 	Modified        :	
# ######################################################################

<# Objective:
	To get collections information from list of collection ID.
#>

<# How to execute:
	Prepare list of collection in C:\temp\collection.txt.
	Ensure you have SCCM management point reachable and have access. 
	Directly run the script with Administrative previlage.
	Provide the collection ID information.
#>

<# Execution:
	Script will connect to SCCM and perform the retreival of collection information.
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

 $location=get-location 
 $InputColor="yellow" 
 $ProcessColor="write-host `$ProcessMessage -ForegroundColor gray -BackgroundColor darkgreen" 
 $collectionlist=gc C:\temp\collection.txt
InitializeSCCM

if($collectionlist)
{
	foreach($col in $collectionlist)
	{
		$col_info=Get-CMCollection -Id $col | select CollectionID,Name,Comment,LimitToCollectionID,LimitToCollectionName ,`
		LocalMemberCunt
		if($col_info)
		{
			write-host "$col does exist in SCCM." -foregroundcolor green
			$ReportTitle="Collection $col $($col_info.name) Details"
			$strPath = "c:\temp\collection_details\$ReportTitle.html" 
			if(test-path $strpath -ea silentlycontinue){remove-item $strpath -force}
			$col_info | ConvertTo-html  -Head $test -Body "<h2>Collection $col Information</h2>" >> "$strPath"   
			$col_rules=Get-CMCollection -Id $col | select -ExpandProperty collectionrules | select 	SmsProviderObjectPath,`
			ExcludeCollectionID,IncludeCollectionID,QueryExpression ,RuleName,Count,Properties
			$col_rules | ConvertTo-html  -Head $test -Body "<h2>Collection $col Rules Information</h2>" >> "$strPath"
		}
		else
		{
			write-host "$col does not exist in SCCM." -foregroundcolor red
			
		}
		$col_rules=$col=$col_info=$null
	}
}
else
{
	write-host "List of collections are not specified under $collectionlist." -foregroundcolor red
}


deinitializeSCCM 
