
# ######################################################################
#
# 	Program         :   SCCM_COLLECTION_WITHNODEPLOYMENT.ps1
# 	Version         :   1.1
# 	Purpose         :   Get the list of collection with NO deployment. 
# 	Author          :	Shishir Kushawaha
#   Technet Link    :   https://gallery.technet.microsoft.com/site/search?f%5B0%5D.Type=User&f%5B0%5D.Value=SHISHIR%20KUSHAWAHA&pageIndex=3 
#	Mail Id         :   srktcet@gmail.com
#   Created         :   07/10/2019 - Script creation.
# 	Modified        :	15-10-2019
#						Added comments
#						Some bug correction
# ######################################################################

<# Objective:
	SCCM have multiple collection which are created by SCCM itself or by user. During course of time the no of collection gets huge.
	However , There may be very old collections which are not of use anymore. However from pool of many collections , its difficult to find the collections where there is no deployments or no member inside the collection. 
	Checking one by one each collection is going to take huge time.
	
	This script is going to automate the same. 
#>

<# How to execute:
	Ensure you have SCCM management point reachable and have access. 
	Directly run the script with Administrative previlage.
#>

<# Execution:
	Script will connect to SCCM and perform the below activity:

	1. Collect list of collections with required parameters like name,collectionid,membercount etc.
	2. Then it will list all the deployment and from them it will extract the collections
	3. Script will compare both the list and extract the collections which are not present in deployment collections list.
	4. Export those list to HTML Page.
#>

function InitializeSCCM 
{ 
	$ProcessMessage="`n Please wait.Initializing SCCM ........." 
	 
	# Site configuration. Please provide site code and sms server information
	$SiteCode=""
	$ProviderMachineName=""
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
		Remove-Item $strPath -Force -ErrorAction SilentlyContinue
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
 $InputColor="yellow" 
 $ProcessColor="write-host `$ProcessMessage -ForegroundColor gray -BackgroundColor darkgreen" 
 $ReportTitle="SCCM COLLECTIONS HAVING NO DEPLOYMENT OR ADVERTISEMENT"
 $strPath = "$location\$ReportTitle.html" 

clear-host
$COLLECTION_RESULT = @()
$COLLECTION_COUNT=0
InitializeSCCM
write-host "Getting entire collection list" -foregroundcolor $inputcolor
$COLLECTION_LIST = Get-CmCollection | Where-Object {$_.CollectionID -notlike 'SMS*' -and $_.CollectionType -eq '2'} | Select Name,MemberCount,CollectionID,IsReferenceCollection,LastMemberChangeTime
write-host "Collection list gathering completed." -foregroundcolor $inputcolor
write-host "Getting entire deployment list" -foregroundcolor $inputcolor
$DEPLOYMENT_List=(Get-CMDeployment).CollectionID
write-host "Deployment list gathering completed." -foregroundcolor $inputcolor	
$TOTAL_COUNT_COLLECTION=$COLLECTION_LIST.count	
$TOTAL_COUNT_DEPLOYMENT=$DEPLOYMENT_List.count	
$COMPARED_RESULT=(Compare-Object $DEPLOYMENT_List $COLLECTION_LIST.collectionid |? {$_.sideindicator -eq "=>"}).inputobject
write-host "I am looking for collections having member count less than OR equal to=" -foregroundcolor $inputcolor -nonewline
$MEMBER_COUNT=read-host 
foreach($c in $COMPARED_RESULT)
	{
        if($COLLECTION_LIST.collectionid -contains $c)
		{
			$result=$COLLECTION_LIST | Where-Object{$_.collectionId -eq $c}
			if($result.membercount -le $MEMBER_COUNT)
			{
				$COLLECTION_RESULT += $result
				$COLLECTION_COUNT++
			}
		}	
	}
deinitializeSCCM
#Writing result to HTML page
write-host "`n Collection information gathering completed." -foregroundcolor $inputcolor
ConvertTo-Html -Head $test -Title $ReportTitle -Body "<h1>SCCM COLLECTIONS HAVING NO DEPLOYMENT OR ADVERTISEMENT</h1>" >  "$strPath"
ConvertTo-Html -Head $test -Title $ReportTitle -Body "<h2> Total collections in entire site : $($TOTAL_COUNT_COLLECTION)</h2>" >  "$strPath"
ConvertTo-Html -Head $test -Title $ReportTitle -Body "<h2> Total deployments in entire site : $($TOTAL_COUNT_DEPLOYMENT)</h2>" >  "$strPath"
$COLLECTION_RESULT | ConvertTo-html  -Head $test -Body "<h2>SCCM COLLECTIONS HAVING NO DEPLOYMENT OR ADVERTISEMENT [Total : $($COLLECTION_COUNT)] </h2>" >> "$strPath"

#Launching HTML generated report 
write-host "`n Opening $strpath report. `n" -foregroundcolor $inputcolor -nonewline 
Invoke-Item $strPath

#Get-WmiObject -Namespace $name_space -Query "select CollectionID,Name,ObjectPath,LimitToCollectionID,LimitToCollectionName,MemberCount from SMS_Collection Where SMS_Collection.collectiontype = 2  and smsm_collection.collectionid not like 'sms*'" -computername $server_name -Credential $CREDENTIAL
#(Get-WmiObject -Namespace $name_space -Query "select collectionid from SMS_DeploymentSummary" -computername $server_name -Credential $CREDENTIAL).collectionid

		


		
				
		

	
  
 
