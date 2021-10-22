# ######################################################################
#
# 	Program         :   DRIVERPACK_TASKSEQUENCE_.ps1
# 	Version         :   1.1
# 	Purpose         :   To find out task sequence reference of driver package
# 	Author          :	Shishir Kushawaha
#	Mail Id         :   srktcet@gmail.com
#   Created         :   27-09-2021 - Script creation.
# 	Modified        :	
# ######################################################################

<# Objective:
	The purpose of this script is to list all driver packages and their assciation with all task sequences.
#>

<# How to execute:
	Ensure you have SCCM management point reachable and have access. 
	Directly run the script with Administrative previlage.
#>

<# Execution:
 
	Script will generate the .HTML page which will have all information in tabular format along with .csv file.

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
 
$ReportTitle="Driver Package task sequence integration matrix"
$strPath = "$location\$ReportTitle.html" 
updateHTML $strPath

#region get all driver pack and task sequnece list
clear-host
$driverPackFinalResult=@()
$driverPackTsAssociationResult=@()
$driverPackageList=$tsList=$null
$driverPackageList=Get-CMDriverPackage -Fast| select name,packageid
$tsList=Get-CMTaskSequence -fast | select name, packageid
write-host "Driver Package and task sequence information gathered."
#endregion

#region package association with task sequnece
foreach($ts in $tsList)
{
    $tempTSResults=$tempTSStagedPackages=$null
    $tempTSResults=Get-CMTaskSequenceStepApplyDriverPackage -TaskSequenceId $($ts.packageid) | select driverpackageid,enabled
	$tempTSStagedPackages=Get-CMTaskSequenceStepDownloadPackageContent -TaskSequenceId $($ts.packageid) | select downloadpackages
    if($null -ne $tempTSResults)
    {
        foreach($tempTSResult in $tempTSResults)
        {
            $tempRecord=[pscustomobject]@{
            'Task Sequence Name'=$ts.name
            'Task Sequence Package ID'=$($ts.packageid)
            'Driver Package ID'=$tempTSResult.driverpackageid
            'Enabled'=$tempTSResult.enabled
            }
            $driverPackTsAssociationResult+=$tempRecord
            $tempRecord=$null
        }
    }
	if($null -ne $tempTSStagedPackages)
    {
        foreach($tempTSStagedPackage in $($tempTSStagedPackages.downloadpackages))
        {
			if($tempTSStagedPackage -in $($driverPackageList.packageid))
			{
				$tempRecord=[pscustomobject]@{
				'Task Sequence Name'=$ts.name
				'Task Sequence Package ID'=$($ts.packageid)
				'Driver Package ID'=$tempTSStagedPackage
				'Enabled'="True"
				}
				$driverPackTsAssociationResult+=$tempRecord
				$tempRecord=$null
			}
        }
    }
}
write-host "Driver Package association with Task Sequence completed."
#endregion end of package association

#region Final report preparation.
foreach($driver in $driverPackageList)
{
    $asscount=0
    foreach($association in $driverPackTsAssociationResult)
    {
        if($driver.packageid -eq $association.'Driver Package ID')
        {
            $asscount++
            $tempDriverResult=[pscustomobject]@{
            'Driver Package Id'=$($driver.packageid)
            'Driver Package Name'=$($driver.name)
            'Associated Task Sequence Package Id'= $($association.'Task Sequence Package ID')
            'Associated Task Sequence Name'= $($association.'Task Sequence Name')
            'Enabled in Task Sequence'= $($association.'Enabled')
            }
            $driverPackFinalResult+=$tempDriverResult
            $tempDriverResult=$null
          }
     }

        if($asscount -eq 0)
        {
            $tempDriverResult=[pscustomobject]@{
            'Driver Package Id'=$($driver.packageid)
            'Driver Package Name'=$($driver.name)
            'Associated Task Sequence Package Id'= "NA"
            'Associated Task Sequence Name'= "NA"
            'Enabled in Task Sequence'= "NA"
            }
            $driverPackFinalResult+=$tempDriverResult
            $tempDriverResult=$null
        }
    }
#endregion for report preparion

#region Report preparation
deinitializeSCCM
$driverPackFinalResult | ConvertTo-Csv "$location\DriverPackTSMatrix.csv" -NoTypeInformation
$driverPackFinalResult | ConvertTo-html  -Head $test -Body "<h2> DriverPackage Task Sequence association</h2>" >> "$strPath"
write-host "`n Openning $strpath report : " -foregroundcolor $inputcolor -nonewline 
Invoke-Item $strPath
#endregion of report preparation 
