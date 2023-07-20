# ######################################################################
#
# 	Program         :   checkTSDistributionStatus.ps1
# 	Version         :   1.0
# 	Purpose         :   Get task sequence's referenced package distribution status on distribution points
# 	Author          :	Shishir Kushawaha
#   Mail Id         :   srktcet@gmail.com
#   Created         :   19-07-2023 - Initial script creation.
# 	Modified        :	
# ######################################################################

<# Objective:
	The purpose of the script list out all the packages referenced by task sequence and check if all those are distributed to specified distribution point.
    The script will prepare a HTML report of all package status.
#>

<# How to execute:
	Ensure you have SCCM management point reachable and have access. 
	Directly run the script with Administrative previlage.
#>

<# Execution:
  This script will accept the task sequence package ID and distribution point name  information from the prompt.
  All the refrenced packages will be checked if they are distributed to distributioin point. If it is distributed, will be marked as distributed else not distributed.
  All the packages status will be merged in a HTML report.
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
    write-host "`n Enter distribution point name : " -foregroundcolor $inputcolor -nonewline 
 	$distributionPoint=read-host 
    $ReportTitle="Task Sequence $taskSequencePackageID distribution details"
	$strPath = "$location\$ReportTitle.html" 
	updateHTML $strPath
	write-host "`n Processing all packages which are integrated in $taskSequencePackageID.Please wait for a min" -ForegroundColor gray -BackgroundColor darkgreen 
    $tsReferences=Get-CMTaskSequence -id $taskSequencePackageID | Select-Object -ExpandProperty references | Select-Object package
    if($tsReferences.count -gt 0)
    {
        $allPackagesOnDP=Get-CMDeploymentPackage -DistributionPointName $distributionPoint | Select-Object Name,Packageid,objectid,@{n='Package Type';e={switch ($_.objecttype) 
            {
                0 { 'Software Distribution Package' }
                3 { 'Driver Package' }
                4 { 'Task Sequence Package' }
                5 { 'Software Update Package' }
                6 {'Device Setting Package'}
                7 {'Virtual Package'}
                512 { 'Applications'}
                257 { 'Image Package'}
                258 {'Boot Image Package'}
                259 { 'Operating System Install Package'}
                Default 
                { 'Unknown'}
            }
        }}

        $report=@()

        foreach($r in $tsReferences)
        {
            $status="Not Distributed"
            foreach($p in $allPackagesOnDP)
            {
                if($r.package -eq $p.objectid)
                {
                    $status="Distributed"
                    $PackageObject=[PSCustomObject]@{
                        'Package Name' = $p.Name
                        'Package ID'=$p.packageid
                        'Object ID'=$p.objectid
                        'Package Type'=$p.'package type'
                        'Status'=$status 
                    }
                    break
                }
            }
            if(($status -eq "Not Distributed") -and !(Get-CMTaskSequence -fast -id $r.package))
            {
                $PackageObject=[PSCustomObject]@{
                    'Package Name' = ""
                    'Package ID'=$r.package
                    'Object ID'=""
                    'Package Type'=""
                    'Status'=$status 
                }
            }
            $report+=$PackageObject 
        }
        if($null -ne $report)
		{
			$report | Sort-Object 'Package ID' -Unique | Sort-Object 'Status' -Descending |  ConvertTo-html  -Head $test -Body "<h2> Task Sequence $taskSequencePackageID referenced packages distribution status on $distributionPoint</h2>" >> "$strPath"
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
